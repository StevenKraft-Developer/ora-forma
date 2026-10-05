const fs = require("fs");
const path = require("path");

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const {
  collection,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  where,
} = require("firebase/firestore");

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "catholic-habits-rules-test",
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
});