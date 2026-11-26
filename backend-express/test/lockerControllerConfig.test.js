const test = require("node:test");
const assert = require("node:assert/strict");
const {
    configureLockerController,
} = require("../configureLockerController");

function createDb({ lockerExists = true, controllerExists = true, assigned = [] } = {}) {
    let updated;
    const db = {
        collection(name) {
            if (name === "lockers") {
                return {
                    doc(id) {
                        return {
                            async get() {
                                return { exists: lockerExists };
                            },
                            async update(data) {
                                updated = { id, data };
                            },
                        };
                    },
                    where(field, operator, value) {
                        assert.deepEqual([field, operator, value], [
                            "controllerId",
                            "==",
                            "esp32_02",
                        ]);
                        return {
                            async get() {
                                return {
                                    docs: assigned.map((item) => ({
                                        id: item.id,
                                        data: () => item.data,
                                    })),
                                };
                            },
                        };
                    },
                };
            }

            assert.equal(name, "controllers");
            return {
                doc() {
                    return {
                        async get() {
                            return {
                                exists: controllerExists,
                                data: () => ({ authToken: "device-token" }),
                            };
                        },
                    };
                },
            };
        },
    };

    return {
        db,
        getUpdated: () => updated,
    };
}

test("unassigning a locker clears only its controller mapping", async () => {
    const fake = createDb();

    await configureLockerController(fake.db, {
        LOCKER_ID: "locker_02",
        CONTROLLER_ID: "",
    });

    assert.deepEqual(fake.getUpdated(), {
        id: "locker_02",
        data: {
            controllerId: null,
            lockerIndex: null,
        },
    });
});

test("assigning a registered controller stores its locker index", async () => {
    const fake = createDb();

    await configureLockerController(fake.db, {
        LOCKER_ID: "locker_02",
        CONTROLLER_ID: "esp32_02",
        LOCKER_INDEX: "0",
    });

    assert.deepEqual(fake.getUpdated(), {
        id: "locker_02",
        data: {
            controllerId: "esp32_02",
            lockerIndex: 0,
        },
    });
});

test("a controller index cannot be assigned to two lockers", async () => {
    const fake = createDb({
        assigned: [{
            id: "locker_01",
            data: { lockerIndex: 0 },
        }],
    });

    await assert.rejects(
        configureLockerController(fake.db, {
            LOCKER_ID: "locker_02",
            CONTROLLER_ID: "esp32_02",
            LOCKER_INDEX: "0",
        }),
        /already assigned to locker_01/,
    );
    assert.equal(fake.getUpdated(), undefined);
});
