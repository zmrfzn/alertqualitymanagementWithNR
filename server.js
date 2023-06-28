const newrelic = require("newrelic")
const express = require("express");

newrelic.instrumentLoadedModule(
    "express",    // the module's name, as a string
    express       // the module instance
  );

const app = express();
const path = require("path");
const router = express.Router();
const bodyParser = require("body-parser");
const cors = require("cors");
const winston = require("winston");
const {chaos} = require("express-chaos-middleware");

// Chaos Monkey
app.use(chaos({
    probability: 20,
    maxDelay: 2000,
  }))

const logger = winston.createLogger({
    level: "info",
    format: winston.format.json(),
    defaultMeta: { service: "pae-service" },
    transports: [
        // - Write all logs with importance level of `error` or less to `error.log`
        // - Write all logs with importance level of `info` or less to `combined.log`
        new winston.transports.File({ filename: "error.log", level: "error" }),
        new winston.transports.File({ filename: "combined.log" }),
    ],
});

app.use(cors());
app.use(bodyParser.json()); // for parsing application/json
app.use(bodyParser.urlencoded({ extended: true })); // for parsing application/x-www-form-urlencoded

app.use(express.static(path.join(__dirname, "/src")));

router.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "/src/index.html"));  
});

app.get("/game", (req, res) => {
  logger.info("Another entry route to the game!");
  res.sendFile(path.join(__dirname, "/src/index.html"));  
});

app.get("/score", (req, res) => {
  let score = Math.floor(Math.random() * (30000 - 10000) + 10000)
  let id = Math.floor(Math.random() * (30 - 1) + 1)

  // Record logs in context via APM
  logger.info(`${req.method} ${req.path} from ${req.hostname}`);
  logger.info(`Player ${id} - ${score}`);

  // Record custom attributes via APM
  // newrelic.addCustomAttributes({
  //   "playerID": id,
  //   "gameScore": score
  // });

  res.status(200).send(`Player ${id} - ${score}`);
});

app.get("/404", (req, res) => {
  logger.warn("Warning at /404");
  logger.warn(`${req.method} ${req.path} from ${req.hostname}`);
  res.sendStatus(404);
});

app.get("/user", (req, res) => {
  try {
    throw new Error("Error! Invalid user!");
  } catch (error) {
    logger.error("Invalid user at /user");
    logger.error(`${req.method} ${req.path} from ${req.hostname}`);
    res.status(500).send("Error! Invalid user!");
  }
});

app.use("/", router);
app.listen(process.env.port || 3000);

logger.info("Starting the game on port 3000");
console.log("Starting the game on port 3000");