// In-memory state per locker
// Format: { [lockerId]: { doorOpen: bool, solenoidOn: bool } }
const state = {};

function init(lockerId) {
    if (!state[lockerId]) {
        state[lockerId] = {
            doorOpen: false,
            solenoidOn: false
        };
    }
}

function update(lockerId, {
    doorOpen,
    solenoidOn
}) {
    if (!state[lockerId]) {
        state[lockerId] = {
            doorOpen: false,
            solenoidOn: false
        };
    }
    state[lockerId].doorOpen = !!doorOpen;
    state[lockerId].solenoidOn = !!solenoidOn;
}

function get(lockerId) {
    return state[lockerId] || {
        doorOpen: false,
        solenoidOn: false
    };
}

function getAll() {
    return state;
}

module.exports = {
    init,
    update,
    get,
    getAll
};