const test = require("node:test");
const assert = require("node:assert/strict");
const {
    getControllerStatuses,
    recordControllerHeartbeat,
    ONLINE_WINDOW_MS,
} = require("../src/services/controllerStatusService");

test("controller status uses the 15-second online window", async () => {
    const now = 1_800_000_000_000;
    const db = {
        collection(name) {
            assert.equal(name, "controllers");
            return {
                async get() {
                    return {
                        docs: [
                            {
                                id: "online",
                                data: () => ({
                                    authToken: "secret",
                                    lastSeenAt: { toMillis: () => now - ONLINE_WINDOW_MS },
                                }),
                            },
                            {
                                id: "offline",
                                data: () => ({
                                    lastSeenAt: { toMillis: () => now - ONLINE_WINDOW_MS - 1 },
                                }),
                            },
                            {
                                id: "never-seen",
                                data: () => ({}),
                            },
                        ],
                    };
                },
            };
        },
    };

    const statuses = await getControllerStatuses(db, now);

    assert.deepEqual(
        statuses.map(({ controller_id, online, last_seen_at }) => ({
            controller_id,
            online,
            last_seen_at,
        })),
        [
            {
                controller_id: "online",
                online: true,
                last_seen_at: new Date(now - ONLINE_WINDOW_MS).toISOString(),
            },
            {
                controller_id: "offline",
                online: false,
                last_seen_at: new Date(now - ONLINE_WINDOW_MS - 1).toISOString(),
            },
            {
                controller_id: "never-seen",
                online: false,
                last_seen_at: null,
            },
        ],
    );
    assert.equal("authToken" in statuses[0], false);
});

test("heartbeat only updates controller last-seen data", async () => {
    let update;
    const db = {
        collection(name) {
            assert.equal(name, "controllers");
            return {
                doc(id) {
                    assert.equal(id, "esp32_01");
                    return {
                        async set(data, options) {
                            update = { data, options };
                        },
                    };
                },
            };
        },
    };

    await recordControllerHeartbeat(db, "esp32_01");

    assert.equal(update.options.merge, true);
    assert.equal(typeof update.data.lastSeenAt.toMillis, "function");
});
