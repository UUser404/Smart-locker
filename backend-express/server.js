const express = require("express");
const cors = require("cors");
const {
  startScheduler
} = require("./src/scheduler");
const {
  initTokenStore
} = require("./src/services/tokenStoreInit");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.json({
    status: "ok",
    message: "Smart Locker backend jalan"
  });
});

app.use("/api/auth", require("./src/routes/auth"));
app.use("/api/lockers", require("./src/routes/lockers"));
app.use("/api/rentals", require("./src/routes/rentals"));
app.use("/api/firmware", require("./src/routes/firmware"));
app.use("/api/admin", require("./src/routes/admin"));

const PORT = process.env.PORT || 3000;

app.listen(PORT, async () => {
  console.log(`Server jalan di port ${PORT}`);

  try {
    await initTokenStore();
  } catch (err) {
    console.error("[tokenStore] Init failed:", err.message);
  }

  startScheduler();
});