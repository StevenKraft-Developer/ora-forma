/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {setGlobalOptions} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

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
