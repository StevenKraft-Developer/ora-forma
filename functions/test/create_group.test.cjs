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

const {createGroup} = require("../lib/index.js");
const {getFirestore} = require("firebase-admin/firestore");
const {getApps, deleteApp} = require("firebase-admin/app");

const db = getFirestore();
const wrappedCreateGroup = functionsTest.wrap(createGroup);

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