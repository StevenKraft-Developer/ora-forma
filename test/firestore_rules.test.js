const fs = require("fs");
const path = require("path");

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
} = require("firebase/firestore");

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-catholic-habits",
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, "..", "firestore.rules"),
        "utf8",
      ),
    },
  });
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

afterAll(async () => {
  await testEnv.cleanup();
});

describe("Firestore user data isolation", () => {
  const userA = "user-a";
  const userB = "user-b";

  test("user A can create and read their profile", async () => {
    const dbA = testEnv.authenticatedContext(userA).firestore();
    const profile = doc(dbA, "users", userA);

    await assertSucceeds(
      setDoc(profile, {
        uid: userA,
        email: "a@example.com",
      }),
    );

    await assertSucceeds(getDoc(profile));
  });

  test("unauthenticated user cannot read a profile", async () => {
    const db = testEnv.unauthenticatedContext().firestore();

    await assertFails(getDoc(doc(db, "users", userA)));
  });

  test("user A can write a habit in their own subtree", async () => {
    const dbA = testEnv.authenticatedContext(userA).firestore();

    await assertSucceeds(
      setDoc(doc(dbA, "users", userA, "habits", "morning_prayer"), {
        title: "Morning Prayer",
        description: null,
        sortOrder: 0,
        isArchived: false,
      }),
    );
  });

  test("user B cannot write under user A", async () => {
    const dbB = testEnv.authenticatedContext(userB).firestore();

    await assertFails(
      setDoc(doc(dbB, "users", userA, "habits", "morning_prayer"), {
        title: "Unauthorized",
        sortOrder: 0,
        isArchived: false,
      }),
    );
  });

  test("user A can write habit metadata", async () => {
    const dbA = testEnv.authenticatedContext(userA).firestore();

    await assertSucceeds(
      setDoc(doc(dbA, "users", userA, "meta", "habits"), {
        initialized: true,
      }),
    );
  });

  test("user A can write a daily log", async () => {
    const dbA = testEnv.authenticatedContext(userA).firestore();

    await assertSucceeds(
      setDoc(doc(dbA, "users", userA, "dailyLogs", "2026-10-05"), {
        dateKey: "2026-10-05",
        completedHabitIds: ["morning_prayer"],
      }),
    );
  });

  test("unauthenticated user cannot write a daily log", async () => {
    const db = testEnv.unauthenticatedContext().firestore();

    await assertFails(
      setDoc(doc(db, "users", userA, "dailyLogs", "2026-10-05"), {
        dateKey: "2026-10-05",
        completedHabitIds: ["morning_prayer"],
      }),
    );
  });

  test("user B cannot read user A's daily log", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "users", userA, "dailyLogs", "2026-10-05"),
        {
          dateKey: "2026-10-05",
          completedHabitIds: ["morning_prayer"],
        },
      );
    });

    const dbB = testEnv.authenticatedContext(userB).firestore();

    await assertFails(
      getDoc(doc(dbB, "users", userA, "dailyLogs", "2026-10-05")),
    );
  });

  test("user A can list their own daily logs", async () => {
    const dbA = testEnv.authenticatedContext(userA).firestore();

    const logs = query(
      collection(dbA, "users", userA, "dailyLogs"),
      where("dateKey", ">=", "2025-10-06"),
      orderBy("dateKey"),
    );

    await assertSucceeds(getDocs(logs));
  });

  test("user B cannot list user A's daily logs", async () => {
    const dbB = testEnv.authenticatedContext(userB).firestore();

    const logs = query(
      collection(dbB, "users", userA, "dailyLogs"),
      where("dateKey", ">=", "2025-10-06"),
      orderBy("dateKey"),
    );

    await assertFails(getDocs(logs));
  });

  test("user A cannot delete their profile", async () => {
  const dbA = testEnv.authenticatedContext(userA).firestore();
  const profile = doc(dbA, "users", userA);

  await assertSucceeds(
    setDoc(profile, {
      uid: userA,
      email: "a@example.com",
    }),
  );

  await assertFails(deleteDoc(profile));
});

describe.each(["habits", "meta", "dailyLogs"])(
  "%s account boundaries",
  (subcollection) => {
    const documentId = "isolation-test";

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(
          doc(
            context.firestore(),
            "users",
            userA,
            subcollection,
            documentId,
          ),
          { marker: "owned-by-a" },
        );
      });
    });

    test("owner can read, update, and delete their document", async () => {
      const dbA = testEnv.authenticatedContext(userA).firestore();
      const target = doc(dbA, "users", userA, subcollection, documentId);

      await assertSucceeds(getDoc(target));
      await assertSucceeds(updateDoc(target, { marker: "updated-by-a" }));
      await assertSucceeds(deleteDoc(target));
    });

    test("another account cannot read, create, update, delete, or list", async () => {
      const dbB = testEnv.authenticatedContext(userB).firestore();
      const target = doc(dbB, "users", userA, subcollection, documentId);

      await assertFails(getDoc(target));
      await assertFails(
        setDoc(doc(dbB, "users", userA, subcollection, "new-document"), {
          marker: "created-by-b",
        }),
      );
      await assertFails(updateDoc(target, { marker: "updated-by-b" }));
      await assertFails(deleteDoc(target));
      await assertFails(
        getDocs(collection(dbB, "users", userA, subcollection)),
      );
    });

    test("unauthenticated clients cannot read, create, update, delete, or list", async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      const target = doc(db, "users", userA, subcollection, documentId);

      await assertFails(getDoc(target));
      await assertFails(
        setDoc(doc(db, "users", userA, subcollection, "new-document"), {
          marker: "unauthenticated",
        }),
      );
      await assertFails(updateDoc(target, { marker: "unauthenticated" }));
      await assertFails(deleteDoc(target));
      await assertFails(
        getDocs(collection(db, "users", userA, subcollection)),
      );
    });
  },
);

});

describe("Group membership access", () => {
  const groupId = "friday-fraternity";
  const ownerUid = "group-owner";
  const memberUid = "group-member";
  const outsiderUid = "group-outsider";

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();

      await setDoc(doc(db, "groups", groupId), {
        name: "Friday Fraternity",
        description: "Weekly brotherhood",
        ownerUid,
      });

      await setDoc(
        doc(db, "groups", groupId, "members", ownerUid),
        {role: "owner"},
      );

      await setDoc(
        doc(db, "groups", groupId, "members", memberUid),
        {role: "member"},
      );

      await setDoc(doc(db, "groupInvites", "test-invite"), {
        groupId,
        createdBy: ownerUid,
      });
    });
  });

  test("owner and member can read their group", async () => {
    for (const uid of [ownerUid, memberUid]) {
      const db = testEnv.authenticatedContext(uid).firestore();

      await assertSucceeds(getDoc(doc(db, "groups", groupId)));
    }
  });

  test("outsider and signed-out client cannot read the group", async () => {
    const contexts = [
      testEnv.authenticatedContext(outsiderUid),
      testEnv.unauthenticatedContext(),
    ];

    for (const context of contexts) {
      await assertFails(
        getDoc(doc(context.firestore(), "groups", groupId)),
      );
    }
  });

  test("a forged discovery index does not grant group access", async () => {
    const db = testEnv.authenticatedContext(outsiderUid).firestore();

    await assertSucceeds(
      setDoc(
        doc(db, "users", outsiderUid, "groupMemberships", groupId),
        {joinedAt: "forged"},
      ),
    );

    await assertFails(getDoc(doc(db, "groups", groupId)));
  });

  test("a forged profile groupIds array does not grant access", async () => {
    const db = testEnv.authenticatedContext(outsiderUid).firestore();

    await assertSucceeds(
      setDoc(doc(db, "users", outsiderUid), {
        groupIds: [groupId],
      }),
    );

    await assertFails(getDoc(doc(db, "groups", groupId)));
  });

  test("even the owner cannot directly create, update, or delete groups", async () => {
    const db = testEnv.authenticatedContext(ownerUid).firestore();

    await assertFails(
      setDoc(doc(db, "groups", "unauthorized-group"), {
        name: "Unauthorized",
        ownerUid,
      }),
    );

    await assertFails(
      updateDoc(doc(db, "groups", groupId), {
        name: "Unauthorized edit",
      }),
    );

    await assertFails(deleteDoc(doc(db, "groups", groupId)));
  });

  test("a member can read their own membership", async () => {
    const db = testEnv.authenticatedContext(memberUid).firestore();

    await assertSucceeds(
      getDoc(doc(db, "groups", groupId, "members", memberUid)),
    );
  });

  test("a member cannot read another membership or list members", async () => {
    const db = testEnv.authenticatedContext(memberUid).firestore();

    await assertFails(
      getDoc(doc(db, "groups", groupId, "members", ownerUid)),
    );

    await assertFails(
      getDocs(collection(db, "groups", groupId, "members")),
    );
  });

  test("an outsider cannot create their own authoritative membership", async () => {
    const db = testEnv.authenticatedContext(outsiderUid).firestore();

    await assertFails(
      setDoc(
        doc(db, "groups", groupId, "members", outsiderUid),
        {role: "owner"},
      ),
    );
  });

  test("a member cannot change their role or delete membership", async () => {
    const db = testEnv.authenticatedContext(memberUid).firestore();
    const membership = doc(
      db, "groups", groupId, "members", memberUid,
    );

    await assertFails(updateDoc(membership, {role: "owner"}));
    await assertFails(deleteDoc(membership));
  });

  test("even the owner cannot directly read, list, or write invites", async () => {
    const db = testEnv.authenticatedContext(ownerUid).firestore();
    const invite = doc(db, "groupInvites", "test-invite");

    await assertFails(getDoc(invite));
    await assertFails(getDocs(collection(db, "groupInvites")));

    await assertFails(
      setDoc(doc(db, "groupInvites", "new-invite"), {groupId}),
    );

    await assertFails(updateDoc(invite, {groupId: "another-group"}));
    await assertFails(deleteDoc(invite));
  });
});