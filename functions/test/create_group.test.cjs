const assert = require("node:assert/strict");
const {
  after,
  beforeEach,
  test,
} = require("node:test");

const projectId = "demo-catholic-habits";

if (
  !["127.0.0.1:8080", "localhost:8080"].includes(
    process.env.FIRESTORE_EMULATOR_HOST,
  )
) {
  throw new Error(
    "Tests require the local Firestore emulator on port 8080.",
  );
}

process.env.GCLOUD_PROJECT = projectId;
process.env.GOOGLE_CLOUD_PROJECT = projectId;

const functionsTest = require("firebase-functions-test")({
  projectId,
});

const {
  createGroup,
  createGroupInvite,
  joinGroup,
} = require("../lib/index.js");

const {
  getFirestore,
  Timestamp,
} = require("firebase-admin/firestore");

const {getApps, deleteApp} = require("firebase-admin/app");

const db = getFirestore();
const wrappedCreateGroup = functionsTest.wrap(createGroup);
const wrappedCreateGroupInvite = functionsTest.wrap(createGroupInvite);
const wrappedJoinGroup = functionsTest.wrap(joinGroup);

function callAsOwner(data) {
  return wrappedCreateGroup({
    data,
    auth: {
      uid: "owner-a",
      token: {},
    },
  });
}

async function clearTestData() {
  await db.recursiveDelete(db.collection("groupInvites"));
  await db.recursiveDelete(db.collection("groups"));
  await db.recursiveDelete(db.collection("users"));
}

async function assertNoGroupWrites() {
  const groups = await db.collection("groups").get();
  const memberships = await db
    .collection("users")
    .doc("owner-a")
    .collection("groupMemberships")
    .get();

  assert.equal(groups.size, 0);
  assert.equal(memberships.size, 0);
}

beforeEach(async () => {
  await clearTestData();
});

after(async () => {
  await clearTestData();
  functionsTest.cleanup();
  await Promise.all(getApps().map((app) => deleteApp(app)));
});

test("rejects a signed-out caller", async () => {
  await assert.rejects(
    () => wrappedCreateGroup({
      data: {name: "Friday Fraternity"},
    }),
    (error) => error.code === "unauthenticated",
  );

  await assertNoGroupWrites();
});

const invalidInputs = [
  ["missing payload", undefined],
  ["null payload", null],
  ["array payload", []],
  ["missing name", {}],
  ["non-text name", {name: 123}],
  ["blank name", {name: "   "}],
  ["oversized name", {name: "a".repeat(81)}],
  ["non-text description", {name: "Group", description: 123}],
  ["null description", {name: "Group", description: null}],
  [
    "oversized description",
    {name: "Group", description: "a".repeat(501)},
  ],
];

for (const [label, input] of invalidInputs) {
  test(`rejects ${label} without writing documents`, async () => {
    await assert.rejects(
      () => callAsOwner(input),
      (error) => error.code === "invalid-argument",
    );

    await assertNoGroupWrites();
  });
}

test("creates a group, owner membership, and discovery index", async () => {
  const result = await callAsOwner({
    name: "  Friday Fraternity  ",
    description: "  Weekly brotherhood  ",
    ownerUid: "someone-else",
  });

  assert.equal(typeof result.groupId, "string");
  assert.ok(result.groupId.length > 0);

  const groupRef = db.collection("groups").doc(result.groupId);
  const memberRef = groupRef.collection("members").doc("owner-a");
  const indexRef = db
    .collection("users")
    .doc("owner-a")
    .collection("groupMemberships")
    .doc(result.groupId);

  const [group, member, index] = await Promise.all([
    groupRef.get(),
    memberRef.get(),
    indexRef.get(),
  ]);

  assert.equal(group.exists, true);
  assert.equal(group.get("name"), "Friday Fraternity");
  assert.equal(group.get("description"), "Weekly brotherhood");
  assert.equal(group.get("ownerUid"), "owner-a");
  assert.equal(typeof group.get("createdAt").toMillis(), "number");

  assert.equal(member.exists, true);
  assert.equal(member.get("role"), "owner");
  assert.equal(typeof member.get("joinedAt").toMillis(), "number");

  assert.equal(index.exists, true);
  assert.equal(typeof index.get("joinedAt").toMillis(), "number");

  const forgedOwner = await groupRef
    .collection("members")
    .doc("someone-else")
    .get();

  assert.equal(forgedOwner.exists, false);
});

test("accepts an omitted description", async () => {
  const {groupId} = await callAsOwner({name: "Early Risers"});
  const group = await db.collection("groups").doc(groupId).get();

  assert.equal(group.get("description"), "");
});

test("accepts the maximum name and description lengths", async () => {
  const {groupId} = await callAsOwner({
    name: "a".repeat(80),
    description: "b".repeat(500),
  });

  const group = await db.collection("groups").doc(groupId).get();

  assert.equal(group.get("name").length, 80);
  assert.equal(group.get("description").length, 500);
});
function callInviteAs(uid, data) {
  return wrappedCreateGroupInvite({
    data,
    auth: {
      uid,
      token: {},
    },
  });
}

async function assertNoInvites() {
  const invites = await db.collection("groupInvites").get();
  assert.equal(invites.size, 0);
}

test("invites: rejects a signed-out caller", async () => {
  await assert.rejects(
    () => wrappedCreateGroupInvite({
      data: {groupId: "some-group"},
    }),
    (error) => error.code === "unauthenticated",
  );

  await assertNoInvites();
});

const invalidInviteInputs = [
  ["missing payload", undefined],
  ["null payload", null],
  ["array payload", []],
  ["missing group ID", {}],
  ["non-text group ID", {groupId: 123}],
  ["empty group ID", {groupId: ""}],
  ["group ID containing a slash", {groupId: "groups/example"}],
  ["oversized group ID", {groupId: "a".repeat(129)}],
];

for (const [label, input] of invalidInviteInputs) {
  test(`invites: rejects ${label}`, async () => {
    await assert.rejects(
      () => callInviteAs("owner-a", input),
      (error) => error.code === "invalid-argument",
    );

    await assertNoInvites();
  });
}

test("invites: rejects an ordinary group member", async () => {
  const {groupId} = await callAsOwner({name: "Friday Fraternity"});

  await db
    .collection("groups")
    .doc(groupId)
    .collection("members")
    .doc("member-b")
    .set({role: "member"});

  await assert.rejects(
    () => callInviteAs("member-b", {groupId}),
    (error) => error.code === "permission-denied",
  );

  await assertNoInvites();
});

test("invites: rejects an outsider even if they submit the owner's UID", async () => {
  const {groupId} = await callAsOwner({name: "Friday Fraternity"});

  await assert.rejects(
    () => callInviteAs("outsider-c", {
      groupId,
      ownerUid: "owner-a",
      createdBy: "owner-a",
    }),
    (error) => error.code === "permission-denied",
  );

  await assertNoInvites();
});

test("invites: rejects an owner without an authoritative membership", async () => {
  const {groupId} = await callAsOwner({name: "Friday Fraternity"});

  await db
    .collection("groups")
    .doc(groupId)
    .collection("members")
    .doc("owner-a")
    .delete();

  await assert.rejects(
    () => callInviteAs("owner-a", {groupId}),
    (error) => error.code === "permission-denied",
  );

  await assertNoInvites();
});

test("invites: rejects an owner whose membership role is not owner", async () => {
  const {groupId} = await callAsOwner({name: "Friday Fraternity"});

  await db
    .collection("groups")
    .doc(groupId)
    .collection("members")
    .doc("owner-a")
    .update({role: "member"});

  await assert.rejects(
    () => callInviteAs("owner-a", {groupId}),
    (error) => error.code === "permission-denied",
  );

  await assertNoInvites();
});

test("invites: an owner-role record alone does not establish ownership", async () => {
  const {groupId} = await callAsOwner({name: "Friday Fraternity"});

  await db
    .collection("groups")
    .doc(groupId)
    .collection("members")
    .doc("member-b")
    .set({role: "owner"});

  await assert.rejects(
    () => callInviteAs("member-b", {groupId}),
    (error) => error.code === "permission-denied",
  );

  await assertNoInvites();
});

test("invites: rejects a nonexistent group", async () => {
  await assert.rejects(
    () => callInviteAs("owner-a", {groupId: "missing-group"}),
    (error) => error.code === "permission-denied",
  );

  await assertNoInvites();
});

test("invites: owner creates an unused invitation expiring in seven days", async () => {
  const {groupId} = await callAsOwner({name: "Friday Fraternity"});

  const before = Date.now();

  const result = await callInviteAs("owner-a", {
    groupId,
    createdBy: "someone-else",
    expiresAt: "2099-01-01T00:00:00.000Z",
    usedBy: "someone-else",
  });

  const after = Date.now();
  const sevenDays = 7 * 24 * 60 * 60 * 1000;

  assert.match(result.inviteCode, /^[a-f0-9]{64}$/);

  const invite = await db
    .collection("groupInvites")
    .doc(result.inviteCode)
    .get();

  assert.equal(invite.exists, true);
  assert.equal(invite.get("groupId"), groupId);
  assert.equal(invite.get("createdBy"), "owner-a");
  assert.equal(invite.get("usedBy"), null);
  assert.equal(invite.get("usedAt"), null);
  assert.equal(typeof invite.get("createdAt").toMillis(), "number");

  const expiryMilliseconds = invite.get("expiresAt").toMillis();

  assert.ok(expiryMilliseconds >= before + sevenDays);
  assert.ok(expiryMilliseconds <= after + sevenDays);

  assert.equal(
    result.expiresAt,
    invite.get("expiresAt").toDate().toISOString(),
  );

  const invites = await db.collection("groupInvites").get();
  assert.equal(invites.size, 1);
});
function callJoinAs(uid, data) {
  return wrappedJoinGroup({
    data,
    auth: {
      uid,
      token: {},
    },
  });
}

async function createJoinFixture() {
  const {groupId} = await callAsOwner({
    name: "Friday Fraternity",
  });

  const {inviteCode} = await callInviteAs("owner-a", {groupId});

  return {
    groupId,
    inviteCode,
    groupRef: db.collection("groups").doc(groupId),
    inviteRef: db.collection("groupInvites").doc(inviteCode),
  };
}

function membershipIndexRef(uid, groupId) {
  return db
    .collection("users")
    .doc(uid)
    .collection("groupMemberships")
    .doc(groupId);
}

async function assertNoJoinRecords(groupId, uid) {
  const member = await db
    .collection("groups")
    .doc(groupId)
    .collection("members")
    .doc(uid)
    .get();

  const index = await membershipIndexRef(uid, groupId).get();

  assert.equal(member.exists, false);
  assert.equal(index.exists, false);
}

test("join: rejects a signed-out caller", async () => {
  const fixture = await createJoinFixture();

  await assert.rejects(
    () => wrappedJoinGroup({
      data: {inviteCode: fixture.inviteCode},
    }),
    (error) => error.code === "unauthenticated",
  );

  const invite = await fixture.inviteRef.get();
  assert.equal(invite.get("usedBy"), null);

  const members = await fixture.groupRef.collection("members").get();
  assert.equal(members.size, 1);
});

const invalidJoinInputs = [
  ["missing payload", undefined],
  ["null payload", null],
  ["array payload", []],
  ["missing code", {}],
  ["non-text code", {inviteCode: 123}],
  ["empty code", {inviteCode: ""}],
  ["short code", {inviteCode: "abc"}],
  ["non-hex code", {inviteCode: "z".repeat(64)}],
  ["code containing a slash", {inviteCode: "/".repeat(64)}],
];

for (const [label, input] of invalidJoinInputs) {
  test(`join: rejects ${label}`, async () => {
    const fixture = await createJoinFixture();

    await assert.rejects(
      () => callJoinAs("member-b", input),
      (error) => error.code === "invalid-argument",
    );

    await assertNoJoinRecords(fixture.groupId, "member-b");

    const invite = await fixture.inviteRef.get();
    assert.equal(invite.get("usedBy"), null);
  });
}

test("join: rejects a nonexistent invitation", async () => {
  const {groupId} = await callAsOwner({name: "Friday Fraternity"});

  await assert.rejects(
    () => callJoinAs("member-b", {inviteCode: "a".repeat(64)}),
    (error) => error.code === "failed-precondition",
  );

  await assertNoJoinRecords(groupId, "member-b");
});

test("join: creates membership and index, and consumes the invitation", async () => {
  const fixture = await createJoinFixture();

  const result = await callJoinAs("member-b", {
    inviteCode: `  ${fixture.inviteCode}  `,
    uid: "someone-else",
    role: "owner",
  });

  assert.deepEqual(result, {
    groupId: fixture.groupId,
    status: "joined",
  });

  const member = await fixture.groupRef
    .collection("members")
    .doc("member-b")
    .get();

  const index = await membershipIndexRef(
    "member-b",
    fixture.groupId,
  ).get();

  const invite = await fixture.inviteRef.get();

  assert.equal(member.get("role"), "member");
  assert.equal(typeof member.get("joinedAt").toMillis(), "number");
  assert.equal(index.exists, true);
  assert.equal(typeof index.get("joinedAt").toMillis(), "number");
  assert.equal(invite.get("usedBy"), "member-b");
  assert.equal(typeof invite.get("usedAt").toMillis(), "number");

  await assertNoJoinRecords(fixture.groupId, "someone-else");

  const group = await fixture.groupRef.get();
  assert.equal(group.get("ownerUid"), "owner-a");
});

test("join: rejects an expired invitation without consuming it", async () => {
  const fixture = await createJoinFixture();

  await fixture.inviteRef.update({
    expiresAt: Timestamp.fromMillis(Date.now() - 60_000),
  });

  await assert.rejects(
    () => callJoinAs("member-b", {
      inviteCode: fixture.inviteCode,
    }),
    (error) => error.code === "failed-precondition",
  );

  await assertNoJoinRecords(fixture.groupId, "member-b");

  const invite = await fixture.inviteRef.get();
  assert.equal(invite.get("usedBy"), null);
  assert.equal(invite.get("usedAt"), null);
});

test("join: another user cannot redeem a consumed invitation", async () => {
  const fixture = await createJoinFixture();

  await callJoinAs("member-b", {inviteCode: fixture.inviteCode});

  await assert.rejects(
    () => callJoinAs("member-c", {
      inviteCode: fixture.inviteCode,
    }),
    (error) => error.code === "failed-precondition",
  );

  await assertNoJoinRecords(fixture.groupId, "member-c");

  const invite = await fixture.inviteRef.get();
  assert.equal(invite.get("usedBy"), "member-b");
});

test("join: repeating a successful join preserves membership timestamps", async () => {
  const fixture = await createJoinFixture();

  await callJoinAs("member-b", {inviteCode: fixture.inviteCode});

  const memberRef = fixture.groupRef.collection("members").doc("member-b");
  const beforeMember = await memberRef.get();
  const beforeInvite = await fixture.inviteRef.get();

  const result = await callJoinAs("member-b", {
    inviteCode: fixture.inviteCode,
  });

  assert.deepEqual(result, {
    groupId: fixture.groupId,
    status: "already-member",
  });

  const afterMember = await memberRef.get();
  const afterInvite = await fixture.inviteRef.get();

  assert.ok(
    beforeMember.get("joinedAt").isEqual(afterMember.get("joinedAt")),
  );
  assert.ok(
    beforeInvite.get("usedAt").isEqual(afterInvite.get("usedAt")),
  );
});

test("join: an existing owner does not consume an unused invitation", async () => {
  const fixture = await createJoinFixture();

  const result = await callJoinAs("owner-a", {
    inviteCode: fixture.inviteCode,
  });

  assert.equal(result.status, "already-member");

  const invite = await fixture.inviteRef.get();
  assert.equal(invite.get("usedBy"), null);
  assert.equal(invite.get("usedAt"), null);

  const owner = await fixture.groupRef
    .collection("members")
    .doc("owner-a")
    .get();

  assert.equal(owner.get("role"), "owner");
});

test("join: rejects an invitation whose group has been deleted", async () => {
  const fixture = await createJoinFixture();

  await fixture.groupRef.delete();

  await assert.rejects(
    () => callJoinAs("member-b", {
      inviteCode: fixture.inviteCode,
    }),
    (error) => error.code === "failed-precondition",
  );

  await assertNoJoinRecords(fixture.groupId, "member-b");

  const invite = await fixture.inviteRef.get();
  assert.equal(invite.get("usedBy"), null);
});

test("join: a forged discovery index does not prevent a legitimate join", async () => {
  const fixture = await createJoinFixture();

  const indexRef = membershipIndexRef("member-b", fixture.groupId);
  await indexRef.set({joinedAt: "forged", role: "owner"});

  const result = await callJoinAs("member-b", {
    inviteCode: fixture.inviteCode,
  });

  assert.equal(result.status, "joined");

  const index = await indexRef.get();
  assert.equal(typeof index.get("joinedAt").toMillis(), "number");
  assert.equal(index.get("role"), undefined);

  const member = await fixture.groupRef
    .collection("members")
    .doc("member-b")
    .get();

  assert.equal(member.get("role"), "member");
});

test(
  "join: only one of two competing users can consume an invitation",
  {timeout: 30_000},
  async () => {
    const fixture = await createJoinFixture();
    const users = ["member-b", "member-c"];

    const results = await Promise.allSettled(
      users.map((uid) => callJoinAs(uid, {
        inviteCode: fixture.inviteCode,
      })),
    );

    const winners = results.filter((result) => result.status === "fulfilled");
    const losers = results.filter((result) => result.status === "rejected");

    assert.equal(winners.length, 1);
    assert.equal(losers.length, 1);
    assert.equal(winners[0].value.status, "joined");
    assert.equal(losers[0].reason.code, "failed-precondition");

    const winnerIndex = results.findIndex(
      (result) => result.status === "fulfilled",
    );

    const winnerUid = users[winnerIndex];
    const loserUid = users[1 - winnerIndex];

    const invite = await fixture.inviteRef.get();
    assert.equal(invite.get("usedBy"), winnerUid);

    const winnerMembership = await fixture.groupRef
      .collection("members")
      .doc(winnerUid)
      .get();

    const winnerIndexDocument = await membershipIndexRef(
      winnerUid,
      fixture.groupId,
    ).get();

    assert.equal(winnerMembership.get("role"), "member");
    assert.equal(winnerIndexDocument.exists, true);

    await assertNoJoinRecords(fixture.groupId, loserUid);
  },
);