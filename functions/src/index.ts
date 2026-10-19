/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {initializeApp} from "firebase-admin/app";
import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import {setGlobalOptions} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {randomBytes} from "node:crypto";

initializeApp();

setGlobalOptions({
  maxInstances: 10,
});

const db = getFirestore();

interface CreateGroupResult {
  groupId: string;
}

function validateGroupInput(data: unknown): {
  name: string;
  description: string;
} {
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    throw new HttpsError(
      "invalid-argument",
      "Provide a group name and an optional description.",
    );
  }

  const input = data as Record<string, unknown>;

  if (typeof input.name !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "Group name must be text.",
    );
  }

  const name = input.name.trim();

  if (name.length < 1 || name.length > 80) {
    throw new HttpsError(
      "invalid-argument",
      "Group name must contain between 1 and 80 characters.",
    );
  }

  if (
    input.description !== undefined &&
    typeof input.description !== "string"
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Group description must be text.",
    );
  }

  const description =
    typeof input.description === "string"
      ? input.description.trim()
      : "";

  if (description.length > 500) {
    throw new HttpsError(
      "invalid-argument",
      "Group description must contain no more than 500 characters.",
    );
  }

  return {name, description};
}

export const createGroup = onCall(
  async (request): Promise<CreateGroupResult> => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in before creating a group.",
      );
    }

    const uid = request.auth.uid;
    const {name, description} = validateGroupInput(request.data);

    const groupRef = db.collection("groups").doc();
    const memberRef = groupRef.collection("members").doc(uid);
    const membershipIndexRef = db
      .collection("users")
      .doc(uid)
      .collection("groupMemberships")
      .doc(groupRef.id);

    const batch = db.batch();

    batch.create(groupRef, {
      name,
      description,
      ownerUid: uid,
      createdAt: FieldValue.serverTimestamp(),
    });

    batch.create(memberRef, {
      role: "owner",
      joinedAt: FieldValue.serverTimestamp(),
    });

    batch.create(membershipIndexRef, {
      joinedAt: FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
    } catch (error) {
      logger.error("createGroup failed to save group documents", {
        groupId: groupRef.id,
        error,
      });

      throw new HttpsError(
        "internal",
        "The group could not be created. Please try again.",
      );
    }

    return {
      groupId: groupRef.id,
    };
  },
);
interface CreateGroupInviteResult {
  inviteCode: string;
  expiresAt: string;
}

export const createGroupInvite = onCall(
  async (request): Promise<CreateGroupInviteResult> => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in before creating an invitation.",
      );
    }

    const data: unknown = request.data;

    if (
      typeof data !== "object" ||
      data === null ||
      Array.isArray(data)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Provide a valid group ID.",
      );
    }

    const input = data as Record<string, unknown>;

    if (
      typeof input.groupId !== "string" ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(input.groupId)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Provide a valid group ID.",
      );
    }

    const uid = request.auth.uid;
    const groupId = input.groupId;
    const groupRef = db.collection("groups").doc(groupId);
    const ownerMembershipRef = groupRef.collection("members").doc(uid);

    const inviteCode = randomBytes(32).toString("hex");
    const inviteRef = db.collection("groupInvites").doc(inviteCode);

    const sevenDaysInMilliseconds = 7 * 24 * 60 * 60 * 1000;
    const expiresAt = Timestamp.fromMillis(
      Date.now() + sevenDaysInMilliseconds,
    );

    try {
      await db.runTransaction(async (transaction) => {
        const group = await transaction.get(groupRef);
        const membership = await transaction.get(ownerMembershipRef);

        if (
          !group.exists ||
          group.get("ownerUid") !== uid ||
          !membership.exists ||
          membership.get("role") !== "owner"
        ) {
          throw new HttpsError(
            "permission-denied",
            "Only the group owner can create an invitation.",
          );
        }

        transaction.create(inviteRef, {
          groupId,
          createdBy: uid,
          createdAt: FieldValue.serverTimestamp(),
          expiresAt,
          usedBy: null,
          usedAt: null,
        });
      });
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

            logger.error("createGroupInvite failed", {
        groupId,
      });

      throw new HttpsError(
        "internal",
        "The invitation could not be created. Please try again.",
      );
    }

    return {
      inviteCode,
      expiresAt: expiresAt.toDate().toISOString(),
    };
  },
);
interface JoinGroupResult {
  groupId: string;
  status: "joined" | "already-member";
}

export const joinGroup = onCall(
  async (request): Promise<JoinGroupResult> => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in before joining a group.",
      );
    }

    const data: unknown = request.data;

    if (
      typeof data !== "object" ||
      data === null ||
      Array.isArray(data)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Provide a valid invitation code.",
      );
    }

    const input = data as Record<string, unknown>;

    if (typeof input.inviteCode !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Provide a valid invitation code.",
      );
    }

    const inviteCode = input.inviteCode.trim();

    if (!/^[a-f0-9]{64}$/.test(inviteCode)) {
      throw new HttpsError(
        "invalid-argument",
        "Provide a valid invitation code.",
      );
    }

    const uid = request.auth.uid;
    const inviteRef = db.collection("groupInvites").doc(inviteCode);

    try {
      return await db.runTransaction(
        async (transaction): Promise<JoinGroupResult> => {
          const invite = await transaction.get(inviteRef);

          if (!invite.exists) {
            throw new HttpsError(
              "failed-precondition",
              "This invitation is unavailable.",
            );
          }

          const groupId: unknown = invite.get("groupId");

          if (
            typeof groupId !== "string" ||
            !/^[A-Za-z0-9_-]{1,128}$/.test(groupId)
          ) {
            throw new HttpsError(
              "failed-precondition",
              "This invitation is unavailable.",
            );
          }

          const groupRef = db.collection("groups").doc(groupId);
          const memberRef = groupRef.collection("members").doc(uid);
          const membershipIndexRef = db
            .collection("users")
            .doc(uid)
            .collection("groupMemberships")
            .doc(groupId);

          const group = await transaction.get(groupRef);
          const membership = await transaction.get(memberRef);

          if (!group.exists) {
            throw new HttpsError(
              "failed-precondition",
              "This invitation is unavailable.",
            );
          }

          if (membership.exists) {
            return {
              groupId,
              status: "already-member",
            };
          }

          const expiresAt: unknown = invite.get("expiresAt");

          if (
            !(expiresAt instanceof Timestamp) ||
            expiresAt.toMillis() <= Date.now() ||
            invite.get("usedBy") !== null ||
            invite.get("usedAt") !== null
          ) {
            throw new HttpsError(
              "failed-precondition",
              "This invitation is expired or has already been used.",
            );
          }

          transaction.create(memberRef, {
            role: "member",
            joinedAt: FieldValue.serverTimestamp(),
          });

          transaction.set(membershipIndexRef, {
            joinedAt: FieldValue.serverTimestamp(),
          });

          transaction.update(inviteRef, {
            usedBy: uid,
            usedAt: FieldValue.serverTimestamp(),
          });

          return {
            groupId,
            status: "joined",
          };
        },
      );
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      // Do not log the invitation code or the raw database error,
      // which could contain the invitation document path.
      logger.error("joinGroup failed");

      throw new HttpsError(
        "internal",
        "The group could not be joined. Please try again.",
      );
    }
  },
);
interface LeaveGroupResult {
  groupId: string;
  status: "left" | "already-left";
}

export const leaveGroup = onCall(
  async (request): Promise<LeaveGroupResult> => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in before leaving a group.",
      );
    }

    const data: unknown = request.data;

    if (
      typeof data !== "object" ||
      data === null ||
      Array.isArray(data)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Provide a valid group ID.",
      );
    }

    const input = data as Record<string, unknown>;

    if (
      typeof input.groupId !== "string" ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(input.groupId)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Provide a valid group ID.",
      );
    }

    const uid = request.auth.uid;
    const groupId = input.groupId;
    const groupRef = db.collection("groups").doc(groupId);
    const memberRef = groupRef.collection("members").doc(uid);
    const membershipIndexRef = db
      .collection("users")
      .doc(uid)
      .collection("groupMemberships")
      .doc(groupId);

    try {
      return await db.runTransaction(
        async (transaction): Promise<LeaveGroupResult> => {
          const group = await transaction.get(groupRef);
          const membership = await transaction.get(memberRef);

          const ownsGroup =
            group.exists && group.get("ownerUid") === uid;

          const hasOwnerRole =
            membership.exists && membership.get("role") === "owner";

          if (ownsGroup || hasOwnerRole) {
            throw new HttpsError(
              "failed-precondition",
              "The group owner cannot leave. Ownership transfer is not available yet.",
            );
          }

          if (membership.exists) {
            transaction.delete(memberRef);
          }

          transaction.delete(membershipIndexRef);

          return {
            groupId,
            status: membership.exists ? "left" : "already-left",
          };
        },
      );
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      logger.error("leaveGroup failed", {
        groupId,
      });

      throw new HttpsError(
        "internal",
        "The group could not be left. Please try again.",
      );
    }
  },
);
