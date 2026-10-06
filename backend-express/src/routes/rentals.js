const express = require("express");
const { db } = require("../firebase");

const router = express.Router();

// GET /api/rentals/:id/status
router.get("/:id/status", async (req, res) => {
  const { id: rentalId } = req.params;

  try {
    const rentalDoc = await db.collection("rentals").doc(rentalId).get();
    if (!rentalDoc.exists) {
      return res
        .status(404)
        .json({ status: "error", message: "RENTAL_NOT_FOUND" });
    }

    const rental = rentalDoc.data();
    const startedAt = rental.startedAt.toDate();

    if (rental.status === "completed") {
      const endedAt = rental.endedAt.toDate();
      return res.status(200).json({
        rental_status: "completed",
        locker_id: rental.lockerId,
        started_at: startedAt.toISOString(),
        ended_at: endedAt.toISOString(),
        total_duration_seconds: rental.totalDurationSeconds,
      });
    }

    // active atau pending_end → tetap tampil "active"
    const elapsed = Math.floor((Date.now() - startedAt.getTime()) / 1000);
    return res.status(200).json({
      rental_status: "active",
      locker_id: rental.lockerId,
      started_at: startedAt.toISOString(),
      elapsed_seconds: elapsed,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ status: "error", message: "SERVER_ERROR" });
  }
});

module.exports = router;
