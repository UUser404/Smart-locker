const express = require("express");
const cors = require("cors");

const app = express();

app.use(cors());
app.use(express.json());

// Health check
app.get("/", (req, res) => {
  res.json({ status: "ok", message: "Smart Locker backend jalan" });
});

// Routes
app.use("/api/lockers", require("./src/routes/lockers"));
app.use("/api/rentals", require("./src/routes/rentals"));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server jalan di port ${PORT}`));
