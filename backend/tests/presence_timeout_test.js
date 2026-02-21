const assert = require("assert");

function isOnline(lastActiveAt, now, timeoutMs) {
  if (!lastActiveAt) return false;
  const diff = now - new Date(lastActiveAt).getTime();
  return diff < timeoutMs;
}

function run() {
  const now = Date.now();
  const recent = new Date(now - 10000);
  const old = new Date(now - 70000);
  assert.strictEqual(isOnline(recent, now, 60000), true);
  assert.strictEqual(isOnline(old, now, 60000), false);
  assert.strictEqual(isOnline(null, now, 60000), false);
  console.log("presence_timeout_test OK");
}

run();

