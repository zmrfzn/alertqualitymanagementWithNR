// const newrelic = require('newrelic')
// const ChaosMonkey = require('chaos-monkey');
const express = require("express");
const app = express();
const path = require("path");
const router = express.Router();
const bodyParser = require("body-parser");
const cors = require("cors");
const winston = require("winston");
// ChaosMonkey.initialize(app);

const logger = winston.createLogger({
    level: "info",
    format: winston.format.json(),
    defaultMeta: { service: "pae-service" },
    transports: [
        //
        // - Write all logs with importance level of `error` or less to `error.log`
        // - Write all logs with importance level of `info` or less to `combined.log`
        //
        new winston.transports.File({ filename: "error.log", level: "error" }),
        new winston.transports.File({ filename: "combined.log" }),
    ],
});

app.use(cors());
app.use(bodyParser.json()); // for parsing application/json
app.use(bodyParser.urlencoded({ extended: true })); // for parsing application/x-www-form-urlencoded

app.use(express.static(path.join(__dirname, "/src")));

router.get("/", function (req, res) {
    res.sendFile(path.join(__dirname, "/src/index.html"));
});

router.get("/game", function (req, res) {
    res.sendFile(path.join(__dirname, "/src/index.html"));
});

app.use("/", router);
app.listen(process.env.port || 3000);

console.log("Listening on port 3000");
