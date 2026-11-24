// FR10 community validation — Firestore security-rules tests.
// Runs ONLY against the local Firestore emulator under a demo- project id
// (never the real Firebase project):  npm test   (see README.md)
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const rules = readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8');
let env;

const post = (overrides = {}) => ({
  userId: 'alice',
  anonymizedUsername: 'Brave Falcon 12',
  content: 'Day 3 without smoking. Feeling proud!',
  category: 'milestone',
  timestamp: '2026-11-23T10:15:00.000',
  ...overrides,
});
const reply = (overrides = {}) => {
  const { category, ...rest } = post({ content: 'You can do this!', ...overrides });
  return rest;
};
const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-quit-companion',
    firestore: { rules },
  });
});
after(async () => env?.cleanup());
beforeEach(async () => env.clearFirestore());

describe('community post create', () => {
  test('a valid post is allowed', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'communityPosts/p1'), post()));
  });

  test('exactly 2000 characters is allowed; 2001 is rejected', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'communityPosts/p1'), post({ content: 'a'.repeat(2000) })));
    await assertFails(setDoc(doc(alice(), 'communityPosts/p2'), post({ content: 'a'.repeat(2001) })));
  });

  for (const [name, content] of [
    ['empty', ''],
    ['whitespace-only', '   \n\t  '],
    ['zero-width-only', '​​﻿'],
  ]) {
    test(`${name} content is rejected`, async () => {
      await assertFails(setDoc(doc(alice(), 'communityPosts/p1'), post({ content })));
    });
  }

  test('missing required fields are rejected', async () => {
    for (const field of ['content', 'category', 'anonymizedUsername', 'timestamp']) {
      const data = post();
      delete data[field];
      await assertFails(setDoc(doc(alice(), `communityPosts/${field}`), data));
    }
  });

  test('malformed values are rejected', async () => {
    await assertFails(setDoc(doc(alice(), 'communityPosts/a'), post({ content: 42 })));
    await assertFails(setDoc(doc(alice(), 'communityPosts/b'), post({ category: 'spam' })));
    await assertFails(setDoc(doc(alice(), 'communityPosts/c'), post({ anonymizedUsername: '' })));
    await assertFails(setDoc(doc(alice(), 'communityPosts/d'), post({ anonymizedUsername: 'x'.repeat(61) })));
    await assertFails(setDoc(doc(alice(), 'communityPosts/e'), post({ timestamp: 123 })));
    await assertFails(setDoc(doc(alice(), 'communityPosts/f'), post({ likeCount: 999 })));
  });

  test('existing ownership rules still hold', async () => {
    await assertFails(setDoc(doc(bob(), 'communityPosts/p1'), post()));
    await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'communityPosts/p1'), post()));
  });
});

describe('existing data and features are preserved', () => {
  beforeEach(async () => {
    // Seed a legacy post that would fail the new rules (e.g. written before
    // FR10) — reads must still work; rules never re-validate stored data.
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'communityPosts/legacy'), {
        userId: 'alice',
        anonymizedUsername: 'Old Name',
        content: 'x'.repeat(2500),
        category: 'tip',
        timestamp: '2026-08-19T09:00:00.000',
        extraLegacyField: true,
      });
    });
  });

  test('signed-in users can still read posts, including legacy ones', async () => {
    await assertSucceeds(getDoc(doc(bob(), 'communityPosts/legacy')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'communityPosts/legacy')));
  });

  test('likes: a user may like and unlike only as themself', async () => {
    await assertSucceeds(setDoc(doc(bob(), 'communityPosts/legacy/likes/bob'), { likedAt: '2026-11-23' }));
    await assertSucceeds(deleteDoc(doc(bob(), 'communityPosts/legacy/likes/bob')));
    await assertFails(setDoc(doc(bob(), 'communityPosts/legacy/likes/alice'), { likedAt: '2026-11-23' }));
  });

  test('posts still cannot be updated or deleted from the client', async () => {
    await assertFails(updateDoc(doc(alice(), 'communityPosts/legacy'), { content: 'edited' }));
    await assertFails(deleteDoc(doc(alice(), 'communityPosts/legacy')));
  });
});

describe('community reply create', () => {
  test('a valid reply is allowed and readable', async () => {
    await assertSucceeds(setDoc(doc(bob(), 'communityPosts/legacy/replies/r1'), reply({ userId: 'bob' })));
    await assertSucceeds(getDoc(doc(alice(), 'communityPosts/legacy/replies/r1')));
  });

  test('blank, over-long, malformed or impersonating replies are rejected', async () => {
    const path = (id) => doc(bob(), `communityPosts/legacy/replies/${id}`);
    await assertFails(setDoc(path('a'), reply({ userId: 'bob', content: '  ' })));
    await assertFails(setDoc(path('b'), reply({ userId: 'bob', content: 'a'.repeat(2001) })));
    await assertFails(setDoc(path('c'), reply({ userId: 'bob', content: null })));
    await assertFails(setDoc(path('d'), { ...reply({ userId: 'bob' }), category: 'tip' }));
    await assertFails(setDoc(path('e'), reply({ userId: 'alice' })));
    await assertSucceeds(setDoc(path('f'), reply({ userId: 'bob', content: 'b'.repeat(2000) })));
  });
});
