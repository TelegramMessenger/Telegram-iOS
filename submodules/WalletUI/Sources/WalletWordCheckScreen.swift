import Foundation
import UIKit
import AppBundle
import AsyncDisplayKit
import Display
import SolidRoundedButtonNode
import AlertUI
import SwiftSignalKit
import AnimatedStickerNode
import WalletCore
import Markdown

private let possibleWordList: [String] = [
    "abandon",
    "ability",
    "able",
    "about",
    "above",
    "absent",
    "absorb",
    "abstract",
    "absurd",
    "abuse",
    "access",
    "accident",
    "account",
    "accuse",
    "achieve",
    "acid",
    "acoustic",
    "acquire",
    "across",
    "act",
    "action",
    "actor",
    "actress",
    "actual",
    "adapt",
    "add",
    "addict",
    "address",
    "adjust",
    "admit",
    "adult",
    "advance",
    "advice",
    "aerobic",
    "affair",
    "afford",
    "afraid",
    "again",
    "age",
    "agent",
    "agree",
    "ahead",
    "aim",
    "air",
    "airport",
    "aisle",
    "alarm",
    "album",
    "alcohol",
    "alert",
    "alien",
    "all",
    "alley",
    "allow",
    "almost",
    "alone",
    "alpha",
    "already",
    "also",
    "alter",
    "always",
    "amateur",
    "amazing",
    "among",
    "amount",
    "amused",
    "analyst",
    "anchor",
    "ancient",
    "anger",
    "angle",
    "angry",
    "animal",
    "ankle",
    "announce",
    "annual",
    "another",
    "answer",
    "antenna",
    "antique",
    "anxiety",
    "any",
    "apart",
    "apology",
    "appear",
    "apple",
    "approve",
    "april",
    "arch",
    "arctic",
    "area",
    "arena",
    "argue",
    "arm",
    "armed",
    "armor",
    "army",
    "around",
    "arrange",
    "arrest",
    "arrive",
    "arrow",
    "art",
    "artefact",
    "artist",
    "artwork",
    "ask",
    "aspect",
    "assault",
    "asset",
    "assist",
    "assume",
    "asthma",
    "athlete",
    "atom",
    "attack",
    "attend",
    "attitude",
    "attract",
    "auction",
    "audit",
    "august",
    "aunt",
    "author",
    "auto",
    "autumn",
    "average",
    "avocado",
    "avoid",
    "awake",
    "aware",
    "away",
    "awesome",
    "awful",
    "awkward",
    "axis",
    "baby",
    "bachelor",
    "bacon",
    "badge",
    "bag",
    "balance",
    "balcony",
    "ball",
    "bamboo",
    "banana",
    "banner",
    "bar",
    "barely",
    "bargain",
    "barrel",
    "base",
    "basic",
    "basket",
    "battle",
    "beach",
    "bean",
    "beauty",
    "because",
    "become",
    "beef",
    "before",
    "begin",
    "behave",
    "behind",
    "believe",
    "below",
    "belt",
    "bench",
    "benefit",
    "best",
    "betray",
    "better",
    "between",
    "beyond",
    "bicycle",
    "bid",
    "bike",
    "bind",
    "biology",
    "bird",
    "birth",
    "bitter",
    "black",
    "blade",
    "blame",
    "blanket",
    "blast",
    "bleak",
    "bless",
    "blind",
    "blood",
    "blossom",
    "blouse",
    "blue",
    "blur",
    "blush",
    "board",
    "boat",
    "body",
    "boil",
    "bomb",
    "bone",
    "bonus",
    "book",
    "boost",
    "border",
    "boring",
    "borrow",
    "boss",
    "bottom",
    "bounce",
    "box",
    "boy",
    "bracket",
    "brain",
    "brand",
    "brass",
    "brave",
    "bread",
    "breeze",
    "brick",
    "bridge",
    "brief",
    "bright",
    "bring",
    "brisk",
    "broccoli",
    "broken",
    "bronze",
    "broom",
    "brother",
    "brown",
    "brush",
    "bubble",
    "buddy",
    "budget",
    "buffalo",
    "build",
    "bulb",
    "bulk",
    "bullet",
    "bundle",
    "bunker",
    "burden",
    "burger",
    "burst",
    "bus",
    "business",
    "busy",
    "butter",
    "buyer",
    "buzz",
    "cabbage",
    "cabin",
    "cable",
    "cactus",
    "cage",
    "cake",
    "call",
    "calm",
    "camera",
    "camp",
    "can",
    "canal",
    "cancel",
    "candy",
    "cannon",
    "canoe",
    "canvas",
    "canyon",
    "capable",
    "capital",
    "captain",
    "car",
    "carbon",
    "card",
    "cargo",
    "carpet",
    "carry",
    "cart",
    "case",
    "cash",
    "casino",
    "castle",
    "casual",
    "cat",
    "catalog",
    "catch",
    "category",
    "cattle",
    "caught",
    "cause",
    "caution",
    "cave",
    "ceiling",
    "celery",
    "cement",
    "census",
    "century",
    "cereal",
    "certain",
    "chair",
    "chalk",
    "champion",
    "change",
    "chaos",
    "chapter",
    "charge",
    "chase",
    "chat",
    "cheap",
    "check",
    "cheese",
    "chef",
    "cherry",
    "chest",
    "chicken",
    "chief",
    "child",
    "chimney",
    "choice",
    "choose",
    "chronic",
    "chuckle",
    "chunk",
    "churn",
    "cigar",
    "cinnamon",
    "circle",
    "citizen",
    "city",
    "civil",
    "claim",
    "clap",
    "clarify",
    "claw",
    "clay",
    "clean",
    "clerk",
    "clever",
    "click",
    "client",
    "cliff",
    "climb",
    "clinic",
    "clip",
    "clock",
    "clog",
    "close",
    "cloth",
    "cloud",
    "clown",
    "club",
    "clump",
    "cluster",
    "clutch",
    "coach",
    "coast",
    "coconut",
    "code",
    "coffee",
    "coil",
    "coin",
    "collect",
    "color",
    "column",
    "combine",
    "come",
    "comfort",
    "comic",
    "common",
    "company",
    "concert",
    "conduct",
    "confirm",
    "congress",
    "connect",
    "consider",
    "control",
    "convince",
    "cook",
    "cool",
    "copper",
    "copy",
    "coral",
    "core",
    "corn",
    "correct",
    "cost",
    "cotton",
    "couch",
    "country",
    "couple",
    "course",
    "cousin",
    "cover",
    "coyote",
    "crack",
    "cradle",
    "craft",
    "cram",
    "crane",
    "crash",
    "crater",
    "crawl",
    "crazy",
    "cream",
    "credit",
    "creek",
    "crew",
    "cricket",
    "crime",
    "crisp",
    "critic",
    "crop",
    "cross",
    "crouch",
    "crowd",
    "crucial",
    "cruel",
    "cruise",
    "crumble",
    "crunch",
    "crush",
    "cry",
    "crystal",
    "cube",
    "culture",
    "cup",
    "cupboard",
    "curious",
    "current",
    "curtain",
    "curve",
    "cushion",
    "custom",
    "cute",
    "cycle",
    "dad",
    "damage",
    "damp",
    "dance",
    "danger",
    "daring",
    "dash",
    "daughter",
    "dawn",
    "day",
    "deal",
    "debate",
    "debris",
    "decade",
    "december",
    "decide",
    "decline",
    "decorate",
    "decrease",
    "deer",
    "defense",
    "define",
    "defy",
    "degree",
    "delay",
    "deliver",
    "demand",
    "demise",
    "denial",
    "dentist",
    "deny",
    "depart",
    "depend",
    "deposit",
    "depth",
    "deputy",
    "derive",
    "describe",
    "desert",
    "design",
    "desk",
    "despair",
    "destroy",
    "detail",
    "detect",
    "develop",
    "device",
    "devote",
    "diagram",
    "dial",
    "diamond",
    "diary",
    "dice",
    "diesel",
    "diet",
    "differ",
    "digital",
    "dignity",
    "dilemma",
    "dinner",
    "dinosaur",
    "direct",
    "dirt",
    "disagree",
    "discover",
    "disease",
    "dish",
    "dismiss",
    "disorder",
    "display",
    "distance",
    "divert",
    "divide",
    "divorce",
    "dizzy",
    "doctor",
    "document",
    "dog",
    "doll",
    "dolphin",
    "domain",
    "donate",
    "donkey",
    "donor",
    "door",
    "dose",
    "double",
    "dove",
    "draft",
    "dragon",
    "drama",
    "drastic",
    "draw",
    "dream",
    "dress",
    "drift",
    "drill",
    "drink",
    "drip",
    "drive",
    "drop",
    "drum",
    "dry",
    "duck",
    "dumb",
    "dune",
    "during",
    "dust",
    "dutch",
    "duty",
    "dwarf",
    "dynamic",
    "eager",
    "eagle",
    "early",
    "earn",
    "earth",
    "easily",
    "east",
    "easy",
    "echo",
    "ecology",
    "economy",
    "edge",
    "edit",
    "educate",
    "effort",
    "egg",
    "eight",
    "either",
    "elbow",
    "elder",
    "electric",
    "elegant",
    "element",
    "elephant",
    "elevator",
    "elite",
    "else",
    "embark",
    "embody",
    "embrace",
    "emerge",
    "emotion",
    "employ",
    "empower",
    "empty",
    "enable",
    "enact",
    "end",
    "endless",
    "endorse",
    "enemy",
    "energy",
    "enforce",
    "engage",
    "engine",
    "enhance",
    "enjoy",
    "enlist",
    "enough",
    "enrich",
    "enroll",
    "ensure",
    "enter",
    "entire",
    "entry",
    "envelope",
    "episode",
    "equal",
    "equip",
    "era",
    "erase",
    "erode",
    "erosion",
    "error",
    "erupt",
    "escape",
    "essay",
    "essence",
    "estate",
    "eternal",
    "ethics",
    "evidence",
    "evil",
    "evoke",
    "evolve",
    "exact",
    "example",
    "excess",
    "exchange",
    "excite",
    "exclude",
    "excuse",
    "execute",
    "exercise",
    "exhaust",
    "exhibit",
    "exile",
    "exist",
    "exit",
    "exotic",
    "expand",
    "expect",
    "expire",
    "explain",
    "expose",
    "express",
    "extend",
    "extra",
    "eye",
    "eyebrow",
    "fabric",
    "face",
    "faculty",
    "fade",
    "faint",
    "faith",
    "fall",
    "false",
    "fame",
    "family",
    "famous",
    "fan",
    "fancy",
    "fantasy",
    "farm",
    "fashion",
    "fat",
    "fatal",
    "father",
    "fatigue",
    "fault",
    "favorite",
    "feature",
    "february",
    "federal",
    "fee",
    "feed",
    "feel",
    "female",
    "fence",
    "festival",
    "fetch",
    "fever",
    "few",
    "fiber",
    "fiction",
    "field",
    "figure",
    "file",
    "film",
    "filter",
    "final",
    "find",
    "fine",
    "finger",
    "finish",
    "fire",
    "firm",
    "first",
    "fiscal",
    "fish",
    "fit",
    "fitness",
    "fix",
    "flag",
    "flame",
    "flash",
    "flat",
    "flavor",
    "flee",
    "flight",
    "flip",
    "float",
    "flock",
    "floor",
    "flower",
    "fluid",
    "flush",
    "fly",
    "foam",
    "focus",
    "fog",
    "foil",
    "fold",
    "follow",
    "food",
    "foot",
    "force",
    "forest",
    "forget",
    "fork",
    "fortune",
    "forum",
    "forward",
    "fossil",
    "foster",
    "found",
    "fox",
    "fragile",
    "frame",
    "frequent",
    "fresh",
    "friend",
    "fringe",
    "frog",
    "front",
    "frost",
    "frown",
    "frozen",
    "fruit",
    "fuel",
    "fun",
    "funny",
    "furnace",
    "fury",
    "future",
    "gadget",
    "gain",
    "galaxy",
    "gallery",
    "game",
    "gap",
    "garage",
    "garbage",
    "garden",
    "garlic",
    "garment",
    "gas",
    "gasp",
    "gate",
    "gather",
    "gauge",
    "gaze",
    "general",
    "genius",
    "genre",
    "gentle",
    "genuine",
    "gesture",
    "ghost",
    "giant",
    "gift",
    "giggle",
    "ginger",
    "giraffe",
    "girl",
    "give",
    "glad",
    "glance",
    "glare",
    "glass",
    "glide",
    "glimpse",
    "globe",
    "gloom",
    "glory",
    "glove",
    "glow",
    "glue",
    "goat",
    "goddess",
    "gold",
    "good",
    "goose",
    "gorilla",
    "gospel",
    "gossip",
    "govern",
    "gown",
    "grab",
    "grace",
    "grain",
    "grant",
    "grape",
    "grass",
    "gravity",
    "great",
    "green",
    "grid",
    "grief",
    "grit",
    "grocery",
    "group",
    "grow",
    "grunt",
    "guard",
    "guess",
    "guide",
    "guilt",
    "guitar",
    "gun",
    "gym",
    "habit",
    "hair",
    "half",
    "hammer",
    "hamster",
    "hand",
    "happy",
    "harbor",
    "hard",
    "harsh",
    "harvest",
    "hat",
    "have",
    "hawk",
    "hazard",
    "head",
    "health",
    "heart",
    "heavy",
    "hedgehog",
    "height",
    "hello",
    "helmet",
    "help",
    "hen",
    "hero",
    "hidden",
    "high",
    "hill",
    "hint",
    "hip",
    "hire",
    "history",
    "hobby",
    "hockey",
    "hold",
    "hole",
    "holiday",
    "hollow",
    "home",
    "honey",
    "hood",
    "hope",
    "horn",
    "horror",
    "horse",
    "hospital",
    "host",
    "hotel",
    "hour",
    "hover",
    "hub",
    "huge",
    "human",
    "humble",
    "humor",
    "hundred",
    "hungry",
    "hunt",
    "hurdle",
    "hurry",
    "hurt",
    "husband",
    "hybrid",
    "ice",
    "icon",
    "idea",
    "identify",
    "idle",
    "ignore",
    "ill",
    "illegal",
    "illness",
    "image",
    "imitate",
    "immense",
    "immune",
    "impact",
    "impose",
    "improve",
    "impulse",
    "inch",
    "include",
    "income",
    "increase",
    "index",
    "indicate",
    "indoor",
    "industry",
    "infant",
    "inflict",
    "inform",
    "inhale",
    "inherit",
    "initial",
    "inject",
    "injury",
    "inmate",
    "inner",
    "innocent",
    "input",
    "inquiry",
    "insane",
    "insect",
    "inside",
    "inspire",
    "install",
    "intact",
    "interest",
    "into",
    "invest",
    "invite",
    "involve",
    "iron",
    "island",
    "isolate",
    "issue",
    "item",
    "ivory",
    "jacket",
    "jaguar",
    "jar",
    "jazz",
    "jealous",
    "jeans",
    "jelly",
    "jewel",
    "job",
    "join",
    "joke",
    "journey",
    "joy",
    "judge",
    "juice",
    "jump",
    "jungle",
    "junior",
    "junk",
    "just",
    "kangaroo",
    "keen",
    "keep",
    "ketchup",
    "key",
    "kick",
    "kid",
    "kidney",
    "kind",
    "kingdom",
    "kiss",
    "kit",
    "kitchen",
    "kite",
    "kitten",
    "kiwi",
    "knee",
    "knife",
    "knock",
    "know",
    "lab",
    "label",
    "labor",
    "ladder",
    "lady",
    "lake",
    "lamp",
    "language",
    "laptop",
    "large",
    "later",
    "latin",
    "laugh",
    "laundry",
    "lava",
    "law",
    "lawn",
    "lawsuit",
    "layer",
    "lazy",
    "leader",
    "leaf",
    "learn",
    "leave",
    "lecture",
    "left",
    "leg",
    "legal",
    "legend",
    "leisure",
    "lemon",
    "lend",
    "length",
    "lens",
    "leopard",
    "lesson",
    "letter",
    "level",
    "liar",
    "liberty",
    "library",
    "license",
    "life",
    "lift",
    "light",
    "like",
    "limb",
    "limit",
    "link",
    "lion",
    "liquid",
    "list",
    "little",
    "live",
    "lizard",
    "load",
    "loan",
    "lobster",
    "local",
    "lock",
    "logic",
    "lonely",
    "long",
    "loop",
    "lottery",
    "loud",
    "lounge",
    "love",
    "loyal",
    "lucky",
    "luggage",
    "lumber",
    "lunar",
    "lunch",
    "luxury",
    "lyrics",
    "machine",
    "mad",
    "magic",
    "magnet",
    "maid",
    "mail",
    "main",
    "major",
    "make",
    "mammal",
    "man",
    "manage",
    "mandate",
    "mango",
    "mansion",
    "manual",
    "maple",
    "marble",
    "march",
    "margin",
    "marine",
    "market",
    "marriage",
    "mask",
    "mass",
    "master",
    "match",
    "material",
    "math",
    "matrix",
    "matter",
    "maximum",
    "maze",
    "meadow",
    "mean",
    "measure",
    "meat",
    "mechanic",
    "medal",
    "media",
    "melody",
    "melt",
    "member",
    "memory",
    "mention",
    "menu",
    "mercy",
    "merge",
    "merit",
    "merry",
    "mesh",
    "message",
    "metal",
    "method",
    "middle",
    "midnight",
    "milk",
    "million",
    "mimic",
    "mind",
    "minimum",
    "minor",
    "minute",
    "miracle",
    "mirror",
    "misery",
    "miss",
    "mistake",
    "mix",
    "mixed",
    "mixture",
    "mobile",
    "model",
    "modify",
    "mom",
    "moment",
    "monitor",
    "monkey",
    "monster",
    "month",
    "moon",
    "moral",
    "more",
    "morning",
    "mosquito",
    "mother",
    "motion",
    "motor",
    "mountain",
    "mouse",
    "move",
    "movie",
    "much",
    "muffin",
    "mule",
    "multiply",
    "muscle",
    "museum",
    "mushroom",
    "music",
    "must",
    "mutual",
    "myself",
    "mystery",
    "myth",
    "naive",
    "name",
    "napkin",
    "narrow",
    "nasty",
    "nation",
    "nature",
    "near",
    "neck",
    "need",
    "negative",
    "neglect",
    "neither",
    "nephew",
    "nerve",
    "nest",
    "net",
    "network",
    "neutral",
    "never",
    "news",
    "next",
    "nice",
    "night",
    "noble",
    "noise",
    "nominee",
    "noodle",
    "normal",
    "north",
    "nose",
    "notable",
    "note",
    "nothing",
    "notice",
    "novel",
    "now",
    "nuclear",
    "number",
    "nurse",
    "nut",
    "oak",
    "obey",
    "object",
    "oblige",
    "obscure",
    "observe",
    "obtain",
    "obvious",
    "occur",
    "ocean",
    "october",
    "odor",
    "off",
    "offer",
    "office",
    "often",
    "oil",
    "okay",
    "old",
    "olive",
    "olympic",
    "omit",
    "once",
    "one",
    "onion",
    "online",
    "only",
    "open",
    "opera",
    "opinion",
    "oppose",
    "option",
    "orange",
    "orbit",
    "orchard",
    "order",
    "ordinary",
    "organ",
    "orient",
    "original",
    "orphan",
    "ostrich",
    "other",
    "outdoor",
    "outer",
    "output",
    "outside",
    "oval",
    "oven",
    "over",
    "own",
    "owner",
    "oxygen",
    "oyster",
    "ozone",
    "pact",
    "paddle",
    "page",
    "pair",
    "palace",
    "palm",
    "panda",
    "panel",
    "panic",
    "panther",
    "paper",
    "parade",
    "parent",
    "park",
    "parrot",
    "party",
    "pass",
    "patch",
    "path",
    "patient",
    "patrol",
    "pattern",
    "pause",
    "pave",
    "payment",
    "peace",
    "peanut",
    "pear",
    "peasant",
    "pelican",
    "pen",
    "penalty",
    "pencil",
    "people",
    "pepper",
    "perfect",
    "permit",
    "person",
    "pet",
    "phone",
    "photo",
    "phrase",
    "physical",
    "piano",
    "picnic",
    "picture",
    "piece",
    "pig",
    "pigeon",
    "pill",
    "pilot",
    "pink",
    "pioneer",
    "pipe",
    "pistol",
    "pitch",
    "pizza",
    "place",
    "planet",
    "plastic",
    "plate",
    "play",
    "please",
    "pledge",
    "pluck",
    "plug",
    "plunge",
    "poem",
    "poet",
    "point",
    "polar",
    "pole",
    "police",
    "pond",
    "pony",
    "pool",
    "popular",
    "portion",
    "position",
    "possible",
    "post",
    "potato",
    "pottery",
    "poverty",
    "powder",
    "power",
    "practice",
    "praise",
    "predict",
    "prefer",
    "prepare",
    "present",
    "pretty",
    "prevent",
    "price",
    "pride",
    "primary",
    "print",
    "priority",
    "prison",
    "private",
    "prize",
    "problem",
    "process",
    "produce",
    "profit",
    "program",
    "project",
    "promote",
    "proof",
    "property",
    "prosper",
    "protect",
    "proud",
    "provide",
    "public",
    "pudding",
    "pull",
    "pulp",
    "pulse",
    "pumpkin",
    "punch",
    "pupil",
    "puppy",
    "purchase",
    "purity",
    "purpose",
    "purse",
    "push",
    "put",
    "puzzle",
    "pyramid",
    "quality",
    "quantum",
    "quarter",
    "question",
    "quick",
    "quit",
    "quiz",
    "quote",
    "rabbit",
    "raccoon",
    "race",
    "rack",
    "radar",
    "radio",
    "rail",
    "rain",
    "raise",
    "rally",
    "ramp",
    "ranch",
    "random",
    "range",
    "rapid",
    "rare",
    "rate",
    "rather",
    "raven",
    "raw",
    "razor",
    "ready",
    "real",
    "reason",
    "rebel",
    "rebuild",
    "recall",
    "receive",
    "recipe",
    "record",
    "recycle",
    "reduce",
    "reflect",
    "reform",
    "refuse",
    "region",
    "regret",
    "regular",
    "reject",
    "relax",
    "release",
    "relief",
    "rely",
    "remain",
    "remember",
    "remind",
    "remove",
    "render",
    "renew",
    "rent",
    "reopen",
    "repair",
    "repeat",
    "replace",
    "report",
    "require",
    "rescue",
    "resemble",
    "resist",
    "resource",
    "response",
    "result",
    "retire",
    "retreat",
    "return",
    "reunion",
    "reveal",
    "review",
    "reward",
    "rhythm",
    "rib",
    "ribbon",
    "rice",
    "rich",
    "ride",
    "ridge",
    "rifle",
    "right",
    "rigid",
    "ring",
    "riot",
    "ripple",
    "risk",
    "ritual",
    "rival",
    "river",
    "road",
    "roast",
    "robot",
    "robust",
    "rocket",
    "romance",
    "roof",
    "rookie",
    "room",
    "rose",
    "rotate",
    "rough",
    "round",
    "route",
    "royal",
    "rubber",
    "rude",
    "rug",
    "rule",
    "run",
    "runway",
    "rural",
    "sad",
    "saddle",
    "sadness",
    "safe",
    "sail",
    "salad",
    "salmon",
    "salon",
    "salt",
    "salute",
    "same",
    "sample",
    "sand",
    "satisfy",
    "satoshi",
    "sauce",
    "sausage",
    "save",
    "say",
    "scale",
    "scan",
    "scare",
    "scatter",
    "scene",
    "scheme",
    "school",
    "science",
    "scissors",
    "scorpion",
    "scout",
    "scrap",
    "screen",
    "script",
    "scrub",
    "sea",
    "search",
    "season",
    "seat",
    "second",
    "secret",
    "section",
    "security",
    "seed",
    "seek",
    "segment",
    "select",
    "sell",
    "seminar",
    "senior",
    "sense",
    "sentence",
    "series",
    "service",
    "session",
    "settle",
    "setup",
    "seven",
    "shadow",
    "shaft",
    "shallow",
    "share",
    "shed",
    "shell",
    "sheriff",
    "shield",
    "shift",
    "shine",
    "ship",
    "shiver",
    "shock",
    "shoe",
    "shoot",
    "shop",
    "short",
    "shoulder",
    "shove",
    "shrimp",
    "shrug",
    "shuffle",
    "shy",
    "sibling",
    "sick",
    "side",
    "siege",
    "sight",
    "sign",
    "silent",
    "silk",
    "silly",
    "silver",
    "similar",
    "simple",
    "since",
    "sing",
    "siren",
    "sister",
    "situate",
    "six",
    "size",
    "skate",
    "sketch",
    "ski",
    "skill",
    "skin",
    "skirt",
    "skull",
    "slab",
    "slam",
    "sleep",
    "slender",
    "slice",
    "slide",
    "slight",
    "slim",
    "slogan",
    "slot",
    "slow",
    "slush",
    "small",
    "smart",
    "smile",
    "smoke",
    "smooth",
    "snack",
    "snake",
    "snap",
    "sniff",
    "snow",
    "soap",
    "soccer",
    "social",
    "sock",
    "soda",
    "soft",
    "solar",
    "soldier",
    "solid",
    "solution",
    "solve",
    "someone",
    "song",
    "soon",
    "sorry",
    "sort",
    "soul",
    "sound",
    "soup",
    "source",
    "south",
    "space",
    "spare",
    "spatial",
    "spawn",
    "speak",
    "special",
    "speed",
    "spell",
    "spend",
    "sphere",
    "spice",
    "spider",
    "spike",
    "spin",
    "spirit",
    "split",
    "spoil",
    "sponsor",
    "spoon",
    "sport",
    "spot",
    "spray",
    "spread",
    "spring",
    "spy",
    "square",
    "squeeze",
    "squirrel",
    "stable",
    "stadium",
    "staff",
    "stage",
    "stairs",
    "stamp",
    "stand",
    "start",
    "state",
    "stay",
    "steak",
    "steel",
    "stem",
    "step",
    "stereo",
    "stick",
    "still",
    "sting",
    "stock",
    "stomach",
    "stone",
    "stool",
    "story",
    "stove",
    "strategy",
    "street",
    "strike",
    "strong",
    "struggle",
    "student",
    "stuff",
    "stumble",
    "style",
    "subject",
    "submit",
    "subway",
    "success",
    "such",
    "sudden",
    "suffer",
    "sugar",
    "suggest",
    "suit",
    "summer",
    "sun",
    "sunny",
    "sunset",
    "super",
    "supply",
    "supreme",
    "sure",
    "surface",
    "surge",
    "surprise",
    "surround",
    "survey",
    "suspect",
    "sustain",
    "swallow",
    "swamp",
    "swap",
    "swarm",
    "swear",
    "sweet",
    "swift",
    "swim",
    "swing",
    "switch",
    "sword",
    "symbol",
    "symptom",
    "syrup",
    "system",
    "table",
    "tackle",
    "tag",
    "tail",
    "talent",
    "talk",
    "tank",
    "tape",
    "target",
    "task",
    "taste",
    "tattoo",
    "taxi",
    "teach",
    "team",
    "tell",
    "ten",
    "tenant",
    "tennis",
    "tent",
    "term",
    "test",
    "text",
    "thank",
    "that",
    "theme",
    "then",
    "theory",
    "there",
    "they",
    "thing",
    "this",
    "thought",
    "three",
    "thrive",
    "throw",
    "thumb",
    "thunder",
    "ticket",
    "tide",
    "tiger",
    "tilt",
    "timber",
    "time",
    "tiny",
    "tip",
    "tired",
    "tissue",
    "title",
    "toast",
    "tobacco",
    "today",
    "toddler",
    "toe",
    "together",
    "toilet",
    "token",
    "tomato",
    "tomorrow",
    "tone",
    "tongue",
    "tonight",
    "tool",
    "tooth",
    "top",
    "topic",
    "topple",
    "torch",
    "tornado",
    "tortoise",
    "toss",
    "total",
    "tourist",
    "toward",
    "tower",
    "town",
    "toy",
    "track",
    "trade",
    "traffic",
    "tragic",
    "train",
    "transfer",
    "trap",
    "trash",
    "travel",
    "tray",
    "treat",
    "tree",
    "trend",
    "trial",
    "tribe",
    "trick",
    "trigger",
    "trim",
    "trip",
    "trophy",
    "trouble",
    "truck",
    "true",
    "truly",
    "trumpet",
    "trust",
    "truth",
    "try",
    "tube",
    "tuition",
    "tumble",
    "tuna",
    "tunnel",
    "turkey",
    "turn",
    "turtle",
    "twelve",
    "twenty",
    "twice",
    "twin",
    "twist",
    "two",
    "type",
    "typical",
    "ugly",
    "umbrella",
    "unable",
    "unaware",
    "uncle",
    "uncover",
    "under",
    "undo",
    "unfair",
    "unfold",
    "unhappy",
    "uniform",
    "unique",
    "unit",
    "universe",
    "unknown",
    "unlock",
    "until",
    "unusual",
    "unveil",
    "update",
    "upgrade",
    "uphold",
    "upon",
    "upper",
    "upset",
    "urban",
    "urge",
    "usage",
    "use",
    "used",
    "useful",
    "useless",
    "usual",
    "utility",
    "vacant",
    "vacuum",
    "vague",
    "valid",
    "valley",
    "valve",
    "van",
    "vanish",
    "vapor",
    "various",
    "vast",
    "vault",
    "vehicle",
    "velvet",
    "vendor",
    "venture",
    "venue",
    "verb",
    "verify",
    "version",
    "very",
    "vessel",
    "veteran",
    "viable",
    "vibrant",
    "vicious",
    "victory",
    "video",
    "view",
    "village",
    "vintage",
    "violin",
    "virtual",
    "virus",
    "visa",
    "visit",
    "visual",
    "vital",
    "vivid",
    "vocal",
    "voice",
    "void",
    "volcano",
    "volume",
    "vote",
    "voyage",
    "wage",
    "wagon",
    "wait",
    "walk",
    "wall",
    "walnut",
    "want",
    "warfare",
    "warm",
    "warrior",
    "wash",
    "wasp",
    "waste",
    "water",
    "wave",
    "way",
    "wealth",
    "weapon",
    "wear",
    "weasel",
    "weather",
    "web",
    "wedding",
    "weekend",
    "weird",
    "welcome",
    "west",
    "wet",
    "whale",
    "what",
    "wheat",
    "wheel",
    "when",
    "where",
    "whip",
    "whisper",
    "wide",
    "width",
    "wife",
    "wild",
    "will",
    "win",
    "window",
    "wine",
    "wing",
    "wink",
    "winner",
    "winter",
    "wire",
    "wisdom",
    "wise",
    "wish",
    "witness",
    "wolf",
    "woman",
    "wonder",
    "wood",
    "wool",
    "word",
    "work",
    "world",
    "worry",
    "worth",
    "wrap",
    "wreck",
    "wrestle",
    "wrist",
    "write",
    "wrong",
    "yard",
    "year",
    "yellow",
    "you",
    "young",
    "youth",
    "zebra",
    "zero",
    "zone",
    "zoo"
]

public enum WalletWordCheckMode {
    case verify(WalletInfo, [String], [Int])
    case `import`
}

public final class WalletWordCheckScreen: ViewController {
    private let context: WalletContext
    private var presentationData: WalletPresentationData
    private let mode: WalletWordCheckMode
    
    private let startTime: Double
    
    private let walletCreatedPreloadState: Promise<WalletCreatedPreloadState?>?
    
    public init(context: WalletContext, mode: WalletWordCheckMode, walletCreatedPreloadState: Promise<WalletCreatedPreloadState?>?) {
        self.context = context
        self.mode = mode
        self.walletCreatedPreloadState = walletCreatedPreloadState
        
        self.presentationData = context.presentationData
        
        let defaultTheme = self.presentationData.theme.navigationBar
        let navigationBarTheme = NavigationBarTheme(buttonColor: defaultTheme.buttonColor, disabledButtonColor: defaultTheme.disabledButtonColor, primaryTextColor: defaultTheme.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: defaultTheme.badgeBackgroundColor, badgeStrokeColor: defaultTheme.badgeStrokeColor, badgeTextColor: defaultTheme.badgeTextColor)
        
        self.startTime = Date().timeIntervalSince1970
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(back: self.presentationData.strings.Wallet_Navigation_Back, close: self.presentationData.strings.Wallet_Navigation_Close)))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.statusBarStyle
        self.navigationPresentation = .modalInLargeLayout
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Wallet_Navigation_Back, style: .plain, target: nil, action: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func backPressed() {
        self.dismiss()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WalletWordCheckScreenNode(presentationData: self.presentationData, mode: self.mode, possibleWordList: possibleWordList, action: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.mode {
            case let .verify(walletInfo, wordList, indices):
                let enteredWords = (strongSelf.displayNode as! WalletWordCheckScreenNode).enteredWords
                var isCorrect = true
                for i in 0 ..< enteredWords.count {
                    if enteredWords[i].lowercased() != wordList[indices[i]] {
                        isCorrect = false
                        break
                    }
                }
                
                if isCorrect {
                    if let navigationController = strongSelf.navigationController as? NavigationController {
                        var controllers = navigationController.viewControllers
                        controllers = controllers.filter { controller in
                            if controller is WalletSplashScreen {
                                return false
                            }
                            if controller is WalletWordDisplayScreen {
                                return false
                            }
                            if controller is WalletWordCheckScreen {
                                return false
                            }
                            return true
                        }
                        let _ = confirmWalletExported(storage: strongSelf.context.storage, publicKey: walletInfo.publicKey).start()
                        controllers.append(WalletSplashScreen(context: strongSelf.context, mode: .successfullyCreated(walletInfo: walletInfo), walletCreatedPreloadState: strongSelf.walletCreatedPreloadState))
                        strongSelf.view.endEditing(true)
                        navigationController.setViewControllers(controllers, animated: true)
                    }
                } else {
                    strongSelf.view.endEditing(true)
                    strongSelf.present(standardTextAlertController(theme: strongSelf.presentationData.theme.alert, title: strongSelf.presentationData.strings.Wallet_WordCheck_IncorrectHeader, text: strongSelf.presentationData.strings.Wallet_WordCheck_IncorrectText, actions: [
                        TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_WordCheck_TryAgain, action: {
                        }),
                        TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Wallet_WordCheck_ViewWords, action: {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.dismiss()
                        })
                    ], actionLayout: .vertical), in: .window(.root))
                }
            case .import:
                let enteredWords = (strongSelf.displayNode as! WalletWordCheckScreenNode).enteredWords
                precondition(enteredWords.count == 24)
                var allWordsAreValid = true
                for word in enteredWords {
                    if !possibleWordList.contains(word) {
                        allWordsAreValid = false
                        break
                    }
                }
                if !allWordsAreValid {
                    strongSelf.view.endEditing(true)
                    strongSelf.present(standardTextAlertController(theme: strongSelf.presentationData.theme.alert, title: strongSelf.presentationData.strings.Wallet_WordImport_IncorrectTitle, text: strongSelf.presentationData.strings.Wallet_WordImport_IncorrectText, actions: [
                        TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_Alert_OK, action: {
                        })
                    ], actionLayout: .vertical), in: .window(.root))
                    return
                }
                
                let displayError: () -> Void = {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.view.endEditing(true)
                    strongSelf.present(standardTextAlertController(theme: strongSelf.presentationData.theme.alert, title: strongSelf.presentationData.strings.Wallet_WordImport_IncorrectTitle, text: strongSelf.presentationData.strings.Wallet_WordImport_IncorrectText, actions: [
                        TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_Alert_OK, action: {
                        })
                    ], actionLayout: .vertical), in: .window(.root))
                }
                
                let _ = (strongSelf.context.getServerSalt()
                |> deliverOnMainQueue).start(next: { serverSalt in
                    let _ = (importWallet(storage: strongSelf.context.storage, tonInstance: strongSelf.context.tonInstance, keychain: strongSelf.context.keychain, wordList: enteredWords, localPassword: serverSalt)
                    |> deliverOnMainQueue).start(next: { walletInfo in
                        guard let strongSelf = self else {
                            return
                        }
                        if let navigationController = strongSelf.navigationController as? NavigationController {
                            var controllers = navigationController.viewControllers
                            controllers = controllers.filter { controller in
                                if controller is WalletSplashScreen {
                                    return false
                                }
                                if controller is WalletWordDisplayScreen {
                                    return false
                                }
                                if controller is WalletWordCheckScreen {
                                    return false
                                }
                                return true
                            }
                            controllers.append(WalletSplashScreen(context: strongSelf.context, mode: .successfullyImported(importedInfo: walletInfo), walletCreatedPreloadState: strongSelf.walletCreatedPreloadState))
                            strongSelf.view.endEditing(true)
                            navigationController.setViewControllers(controllers, animated: true)
                        }
                    }, error: { error in
                        displayError()
                    })
                }, error: { _ in
                    displayError()
                })
            }
        }, secondaryAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.view.endEditing(true)
            if let navigationController = strongSelf.navigationController as? NavigationController {
                var controllers = navigationController.viewControllers
                controllers = controllers.filter { controller in
                    if controller is WalletSplashScreen {
                        return false
                    }
                    if controller is WalletWordCheckScreen {
                        return false
                    }
                    return true
                }
                controllers.append(WalletSplashScreen(context: strongSelf.context, mode: .restoreFailed, walletCreatedPreloadState: nil))
                navigationController.setViewControllers(controllers, animated: true)
            }
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! WalletWordCheckScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

private func generateClearIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Wallet/ClearInput"), color: color)
}

private final class WordCheckInputNode: ASDisplayNode, UITextFieldDelegate {
    private let previous: (WordCheckInputNode) -> Void
    private let next: (WordCheckInputNode, Bool) -> Void
    private let focused: (WordCheckInputNode) -> Void
    private let pasteWords: ([String]) -> Void
    
    private let backgroundNode: ASImageNode
    private let labelNode: ImmediateTextNode
    private let inputNode: TextFieldNode
    private let clearButtonNode: HighlightableButtonNode
    
    public private(set) var isLast: Bool
    
    var text: String {
        get {
            return self.inputNode.textField.text ?? ""
        } set(value) {
            self.inputNode.textField.text = value
            self.textFieldChanged(self.inputNode.textField)
        }
    }
    
    init(theme: WalletTheme, index: Int, possibleWordList: [String], previous: @escaping (WordCheckInputNode) -> Void, next: @escaping (WordCheckInputNode, Bool) -> Void, isLast: Bool, focused: @escaping (WordCheckInputNode) -> Void, pasteWords: @escaping ([String]) -> Void) {
        self.previous = previous
        self.next = next
        self.focused = focused
        self.pasteWords = pasteWords
        self.isLast = isLast
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 20.0, color: theme.setup.inputBackgroundColor)
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.attributedText = NSAttributedString(string: "\(index + 1):", font: Font.regular(17.0), textColor: theme.setup.inputPlaceholderColor)
        self.labelNode.textAlignment = .right
        
        self.inputNode = TextFieldNode()
        self.inputNode.textField.font = Font.regular(17.0)
        self.inputNode.textField.textColor = theme.setup.inputTextColor
        var wordTapped: ((String) -> Void)?
        self.inputNode.textField.inputAccessoryView = WordCheckInputAccesssoryView(theme: theme, wordList: possibleWordList, wordTapped: { word in
            wordTapped?(word)
        })
        self.inputNode.textField.keyboardType = .asciiCapable
        self.inputNode.textField.autocorrectionType = .no
        self.inputNode.textField.autocapitalizationType = .none
        self.inputNode.textField.spellCheckingType = .no
        if #available(iOS 11.0, *) {
            self.inputNode.textField.smartQuotesType = .no
            self.inputNode.textField.smartDashesType = .no
            self.inputNode.textField.smartInsertDeleteType = .no
        }
        if isLast {
            self.inputNode.textField.returnKeyType = .done
        } else {
            self.inputNode.textField.returnKeyType = .next
        }
        self.inputNode.textField.keyboardAppearance = theme.keyboardAppearance
        
        self.clearButtonNode = HighlightableButtonNode()
        self.clearButtonNode.setImage(generateClearIcon(color: theme.setup.inputClearButtonColor), for: [])
        self.clearButtonNode.isHidden = true
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.inputNode)
        self.addSubnode(self.clearButtonNode)
        
        self.inputNode.textField.didDeleteBackwardWhileEmpty = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.previous(strongSelf)
        }
        self.inputNode.textField.delegate = self
        self.inputNode.textField.addTarget(self, action: #selector(self.textFieldChanged(_:)), for: .editingChanged)
        
        self.clearButtonNode.addTarget(self, action: #selector(self.clearPressed), forControlEvents: .touchUpInside)
        
        wordTapped = { [weak self] word in
            guard let strongSelf = self else {
                return
            }
            strongSelf.inputNode.textField.text = word
            strongSelf.next(strongSelf, false)
        }
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let text = self.text
        let isEmpty = text.isEmpty
        self.clearButtonNode.isHidden = isEmpty
        (self.inputNode.textField.inputAccessoryView as? WordCheckInputAccesssoryView)?.updateText(text)
        self.focused(self)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.clearButtonNode.isHidden = true
        (self.inputNode.textField.inputAccessoryView as? WordCheckInputAccesssoryView)?.updateText("")
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.next(self, true)
        return false
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let wordList = string.lowercased().split(separator: " ")
        if wordList.count == 24 {
            self.pasteWords(wordList.map(String.init))
            return false
        }
        return true
    }
    
    @objc private func textFieldChanged(_ textField: UITextField) {
        let text = self.text
        if textField.isFirstResponder {
            let isEmpty = text.isEmpty
            self.clearButtonNode.isHidden = isEmpty
            (self.inputNode.textField.inputAccessoryView as? WordCheckInputAccesssoryView)?.updateText(text)
        }
    }
    
    @objc private func clearPressed() {
        self.inputNode.textField.text = ""
        self.textFieldChanged(self.inputNode.textField)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let leftInset: CGFloat = 38.0
        let textInset: CGFloat = 5.0
        let rightInset: CGFloat = 38.0
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        let labelSize = self.labelNode.updateLayout(size)
        transition.updateFrameAdditive(node: self.labelNode, frame: CGRect(origin: CGPoint(x: leftInset - labelSize.width, y: floor((size.height - labelSize.height) / 2.0)), size: labelSize))
        transition.updateFrame(node: self.inputNode, frame: CGRect(origin: CGPoint(x: leftInset + textInset, y: 0.0), size: CGSize(width: size.width - leftInset - textInset - rightInset, height: size.height)))
        transition.updateFrame(node: self.clearButtonNode, frame: CGRect(origin: CGPoint(x: size.width - rightInset - 4.0, y: 0.0), size: CGSize(width: rightInset + 4.0, height: size.height)))
    }
    
    func focus() {
        self.inputNode.textField.becomeFirstResponder()
    }
}

private final class WordView: UIView {
    let string: String
    let tapped: () -> Void
    
    let textNode: ImmediateTextNode
    let separator: UIView
    
    init(theme: WalletTheme, string: String, tapped: @escaping () -> Void) {
        self.string = string
        self.tapped = tapped
        
        let separatorColor: UIColor
        let textColor: UIColor
        switch theme.keyboardAppearance {
        case .light, .default:
            separatorColor = UIColor(rgb: 0x9e9f9f)
            textColor = .black
        default:
            separatorColor = UIColor(rgb: 0x9e9f9f)
            textColor = .white
        }
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: string, font: Font.regular(17.0), textColor: textColor)
        self.textNode.isUserInteractionEnabled = false
        
        self.separator = UIView()
        self.separator.backgroundColor = separatorColor
        self.separator.isUserInteractionEnabled = false
        
        super.init(frame: CGRect())
        
        self.addSubview(self.separator)
        self.addSubnode(self.textNode)
        
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped()
        }
    }
    
    func updateLayout(size: CGSize) {
        let textSize = self.textNode.updateLayout(size)
        self.textNode.frame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: floor((size.height - textSize.height) / 2.0)), size: textSize)
        
        self.separator.frame = CGRect(origin: CGPoint(x: size.width - UIScreenPixel, y: floor((size.height - 24.0) / 2.0)), size: CGSize(width: UIScreenPixel, height: 24.0))
    }
}

private final class WordCheckInputAccesssoryView: UIInputView {
    private let theme: WalletTheme
    private let wordList: [String]
    private let wordTapped: (String) -> Void
    
    private var currentText: String = ""
    private let scrollView: UIScrollView
    private var wordViews: [WordView] = []
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 100.0, height: 44.0)
    }
    
    init(theme: WalletTheme, wordList: [String], wordTapped: @escaping (String) -> Void) {
        self.theme = theme
        self.wordList = wordList
        self.wordTapped = wordTapped
        
        self.scrollView = UIScrollView()
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        
        super.init(frame: CGRect(origin: CGPoint(), size: CGSize(width: 100.0, height: 44.0)), inputViewStyle: .keyboard)
        
        self.addSubview(self.scrollView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        UIView.performWithoutAnimation {
            self.update(size: self.bounds.size)
        }
    }
    
    func updateText(_ text: String) {
        var words: [String] = []
        if !text.isEmpty {
            if !self.currentText.isEmpty && text.hasPrefix(self.currentText) {
                for wordView in self.wordViews {
                    if wordView.string.hasPrefix(text) {
                        words.append(wordView.string)
                    }
                }
            } else {
                for word in self.wordList {
                    if word.hasPrefix(text) {
                        words.append(word)
                    }
                }
            }
        }
        self.currentText = text
        var updatedWordViews: [WordView] = []
        if !text.isEmpty {
            for i in 0 ..< words.count {
                let word = words[i]
                var found = false
                for view in self.wordViews {
                    if view.string == word {
                        view.separator.isHidden = i == words.count - 1
                        updatedWordViews.append(view)
                        found = true
                        break
                    }
                }
                if !found {
                    let wordView = WordView(theme: self.theme, string: word, tapped: { [weak self] in
                        self?.wordTapped(word)
                    })
                    wordView.separator.isHidden = i == words.count - 1
                    updatedWordViews.append(wordView)
                    self.scrollView.addSubview(wordView)
                }
            }
        }
        for view in self.wordViews {
            if !updatedWordViews.contains(where: { $0 === view }) {
                view.removeFromSuperview()
            }
        }
        self.wordViews = updatedWordViews
        if !self.bounds.width.isZero {
            self.update(size: self.bounds.size)
        }
    }
    
    func update(size: CGSize) {
        var contentWidth: CGFloat = 0.0
        let wordWidth: CGFloat = 140.0
        for wordView in self.wordViews {
            let wordFrame = CGRect(origin: CGPoint(x: contentWidth, y: 0.0), size: CGSize(width: wordWidth, height: size.height))
            wordView.frame = wordFrame
            wordView.updateLayout(size: wordFrame.size)
            contentWidth += wordWidth
        }
        self.scrollView.frame = CGRect(origin: CGPoint(), size: size)
        self.scrollView.contentSize = CGSize(width: contentWidth, height: size.height)
    }
}

private final class WalletWordCheckScreenNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private var presentationData: WalletPresentationData
    private let mode: WalletWordCheckMode
    private let action: () -> Void
    private let secondaryAction: () -> Void
    
    private let navigationBackgroundNode: ASDisplayNode
    private let navigationSeparatorNode: ASDisplayNode
    private let scrollNode: ASScrollNode
    private let animationNode: AnimatedStickerNode
    private let titleNodeContainer: ASDisplayNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let secondaryActionTitleNode: ImmediateTextNode
    private let secondaryActionButtonNode: HighlightTrackingButtonNode
    private let inputNodes: [WordCheckInputNode]
    private let buttonNode: SolidRoundedButtonNode
    
    private var navigationHeight: CGFloat?
    
    var enteredWords: [String] {
        return self.inputNodes.map { $0.text }
    }
    
    init(presentationData: WalletPresentationData, mode: WalletWordCheckMode, possibleWordList: [String], action: @escaping () -> Void, secondaryAction: @escaping () -> Void) {
        self.presentationData = presentationData
        self.mode = mode
        self.action = action
        self.secondaryAction = secondaryAction
        
        self.navigationBackgroundNode = ASDisplayNode()
        self.navigationBackgroundNode.backgroundColor = self.presentationData.theme.navigationBar.backgroundColor
        self.navigationBackgroundNode.alpha = 0.0
        self.navigationSeparatorNode = ASDisplayNode()
        self.navigationSeparatorNode.backgroundColor = self.presentationData.theme.navigationBar.separatorColor
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.canCancelAllTouchesInViews = true
        
        self.animationNode = AnimatedStickerNode()
        
        let title: String
        let text: NSAttributedString
        let buttonText: String
        let secondaryActionText: String
        
        let wordIndices: [Int]
        
        switch mode {
        case let .verify(_, _, indices):
            wordIndices = indices
            title = self.presentationData.strings.Wallet_WordCheck_Title
            
            let body = MarkdownAttributeSet(font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor, additionalAttributes: [:])
            let bold = MarkdownAttributeSet(font: Font.bold(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor, additionalAttributes: [NSAttributedString.Key.underlineStyle.rawValue: NSUnderlineStyle.single.rawValue as NSNumber])
            text = parseMarkdownIntoAttributedString(self.presentationData.strings.Wallet_WordCheck_Text("\(wordIndices[0] + 1)", "\(wordIndices[1] + 1)", "\(wordIndices[2] + 1)").0, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in nil }), textAlignment: .center)
            
            buttonText = self.presentationData.strings.Wallet_WordCheck_Continue
            secondaryActionText = ""
            if let path = getAppBundle().path(forResource: "WalletWordCheck", ofType: "tgs") {
                self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 238, height: 238, playbackMode: .once, mode: .direct)
                self.animationNode.visibility = true
            }
        case .import:
            title = self.presentationData.strings.Wallet_WordImport_Title
            text = NSAttributedString(string: self.presentationData.strings.Wallet_WordImport_Text, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
            buttonText = self.presentationData.strings.Wallet_WordImport_Continue
            secondaryActionText = self.presentationData.strings.Wallet_WordImport_CanNotRemember
            wordIndices = Array(0 ..< 24)
        }
        
        self.titleNodeContainer = ASDisplayNode()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(32.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = text
        self.textNode.maximumNumberOfLines = 0
        self.textNode.lineSpacing = 0.1
        self.textNode.textAlignment = .center
        
        self.secondaryActionTitleNode = ImmediateTextNode()
        self.secondaryActionTitleNode.isUserInteractionEnabled = false
        self.secondaryActionTitleNode.displaysAsynchronously = false
        self.secondaryActionTitleNode.attributedText = NSAttributedString(string: secondaryActionText, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemAccentColor)
        
        self.secondaryActionButtonNode = HighlightTrackingButtonNode()
        
        var inputNodes: [WordCheckInputNode] = []
        
        var previousWord: ((WordCheckInputNode) -> Void)?
        var nextWord: ((WordCheckInputNode, Bool) -> Void)?
        var focused: ((WordCheckInputNode) -> Void)?
        var pasteWords: (([String]) -> Void)?
        
        for i in 0 ..< wordIndices.count {
            inputNodes.append(WordCheckInputNode(theme: presentationData.theme, index: wordIndices[i], possibleWordList: possibleWordList, previous: { node in
                previousWord?(node)
            }, next: { node, done in
                nextWord?(node, done)
            }, isLast: i == wordIndices.count - 1, focused: { node in
                focused?(node)
            }, pasteWords: { wordList in
                pasteWords?(wordList)
            }))
        }
        
        self.inputNodes = inputNodes
        
        self.buttonNode = SolidRoundedButtonNode(title: buttonText, theme: SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.setup.buttonFillColor, foregroundColor: self.presentationData.theme.setup.buttonForegroundColor), height: 50.0, cornerRadius: 10.0, gloss: false)
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.scrollNode)
        
        self.scrollNode.addSubnode(self.animationNode)
        self.scrollNode.addSubnode(self.textNode)
        self.scrollNode.addSubnode(self.secondaryActionTitleNode)
        self.scrollNode.addSubnode(self.secondaryActionButtonNode)
        self.scrollNode.addSubnode(self.buttonNode)
        
        for (inputNode) in self.inputNodes {
            self.scrollNode.addSubnode(inputNode)
        }
        
        self.navigationBackgroundNode.addSubnode(self.navigationSeparatorNode)
        self.addSubnode(self.navigationBackgroundNode)
        
        self.titleNodeContainer.addSubnode(self.titleNode)
        self.addSubnode(self.titleNodeContainer)
        
        self.buttonNode.pressed = {
            action()
        }
        
        self.secondaryActionButtonNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.secondaryActionTitleNode.layer.removeAnimation(forKey: "opacity")
                strongSelf.secondaryActionTitleNode.alpha = 0.4
            } else {
                strongSelf.secondaryActionTitleNode.alpha = 1.0
                strongSelf.secondaryActionTitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        
        self.secondaryActionButtonNode.addTarget(self, action: #selector(self.secondaryActionPressed), forControlEvents: .touchUpInside)
        
        previousWord = { [weak self] node in
            guard let strongSelf = self else {
                return
            }
            if let index = strongSelf.inputNodes.firstIndex(where: { $0 === node }), index != 0 {
                strongSelf.inputNodes[index - 1].focus()
            }
        }
        nextWord = { [weak self] node, done in
            guard let strongSelf = self else {
                return
            }
            if let index = strongSelf.inputNodes.firstIndex(where: { $0 === node }) {
                if index == strongSelf.inputNodes.count - 1 {
                    if done {
                        action()
                    }
                } else {
                    strongSelf.inputNodes[index + 1].focus()
                }
            }
        }
        focused = { [weak self] node in
            DispatchQueue.main.async {
                guard let strongSelf = self else {
                    return
                }
                if node.isLast {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.scrollNode.view.scrollRectToVisible(strongSelf.buttonNode.frame.insetBy(dx: 0.0, dy: -20.0), animated: false)
                    })
                } else {
                    strongSelf.scrollNode.view.scrollRectToVisible(node.frame.insetBy(dx: 0.0, dy: -10.0), animated: true)
                }
            }
        }
        pasteWords = { [weak self] wordList in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.inputNodes.count == wordList.count {
                for i in 0 ..< strongSelf.inputNodes.count {
                    strongSelf.inputNodes[i].text = wordList[i]
                }
            }
        }
    }
    
    @objc private func secondaryActionPressed() {
        self.secondaryAction()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.keyboardDismissMode = .interactive
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.alwaysBounceVertical = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.scrollNode.view.delegate = self
    }
    
    private var listTitleFrame: CGRect?
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateTitle()
    }
    
    private func updateTitle() {
        guard let listTitleFrame = self.listTitleFrame else {
            return
        }
        let scrollView = self.scrollNode.view
        
        let navigationHeight = self.navigationHeight ?? 0.0
        let minY = navigationHeight - 44.0 + floor(44.0 / 2.0)
        let maxY = minY + 44.0
        let y = max(minY, -scrollView.contentOffset.y + listTitleFrame.midY)
        var t = (y - minY) / (maxY - minY)
        t = max(0.0, min(1.0, t))
        
        let minScale: CGFloat = 0.5
        let maxScale: CGFloat = 1.0
        let scale = t * maxScale + (1.0 - t) * minScale
        
        self.titleNodeContainer.frame = CGRect(origin: CGPoint(x: scrollView.bounds.width / 2.0, y: y), size: CGSize())
        self.titleNodeContainer.subnodeTransform = CATransform3DMakeScale(scale, scale, 1.0)
        
        let alpha: CGFloat = (t <= 0.0 + CGFloat.ulpOfOne) ? 1.0 : 0.0
        if self.navigationBackgroundNode.alpha != alpha {
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
            transition.updateAlpha(node: self.navigationBackgroundNode, alpha: alpha, beginWithCurrentState: true)
        }
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.navigationHeight = navigationHeight
        
        let contentAreaSize = layout.size
        let availableAreaSize = CGSize(width: layout.size.width, height: layout.size.height - layout.insets(options: [.input]).bottom)
        
        let sideInset: CGFloat = 32.0
        let buttonSideInset: CGFloat = 48.0
        let iconSpacing: CGFloat = 9.0
        let titleSpacing: CGFloat = 19.0
        let textSpacing: CGFloat = 30.0
        let buttonHeight: CGFloat = 50.0
        let buttonSpacing: CGFloat = 20.0
        let rowSpacing: CGFloat = 20.0
        
        transition.updateFrame(node: self.navigationBackgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: contentAreaSize.width, height: navigationHeight)))
        transition.updateFrame(node: self.navigationSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: contentAreaSize.width, height: UIScreenPixel)))
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: contentAreaSize))
        
        let iconSize: CGSize
        switch self.mode {
        case .import:
            iconSize = CGSize()
        case .verify:
            iconSize = CGSize(width: 119.0, height: 119.0)
            self.animationNode.updateLayout(size: iconSize)
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: contentAreaSize.width - sideInset * 2.0, height: contentAreaSize.height))
        let textSize = self.textNode.updateLayout(CGSize(width: contentAreaSize.width - sideInset * 2.0, height: contentAreaSize.height))
        let secondaryActionSize = self.secondaryActionTitleNode.updateLayout(CGSize(width: contentAreaSize.width - sideInset * 2.0, height: contentAreaSize.height))
        
        var contentHeight: CGFloat = 0.0
        
        let contentVerticalOrigin = navigationHeight + 10.0
        
        let iconFrame = CGRect(origin: CGPoint(x: floor((contentAreaSize.width - iconSize.width) / 2.0), y: contentVerticalOrigin), size: iconSize)
        transition.updateFrame(node: self.animationNode, frame: iconFrame)
        let titleFrame = CGRect(origin: CGPoint(x: floor((contentAreaSize.width - titleSize.width) / 2.0), y: iconFrame.maxY + iconSpacing), size: titleSize)
        self.listTitleFrame = titleFrame
        transition.updateFrameAdditive(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((-titleFrame.width) / 2.0), y: floor((-titleFrame.height) / 2.0)), size: titleFrame.size))
        let textFrame = CGRect(origin: CGPoint(x: floor((contentAreaSize.width - textSize.width) / 2.0), y: titleFrame.maxY + titleSpacing), size: textSize)
        transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
        
        contentHeight = textFrame.maxY + textSpacing
        
        if !secondaryActionSize.width.isZero {
            let secondaryActionFrame = CGRect(origin: CGPoint(x: floor((contentAreaSize.width - secondaryActionSize.width) / 2.0), y: contentHeight), size: secondaryActionSize)
            transition.updateFrameAdditive(node: self.secondaryActionTitleNode, frame: secondaryActionFrame)
            transition.updateFrame(node: self.secondaryActionButtonNode, frame: secondaryActionFrame.insetBy(dx: -10.0, dy: -10.0))
            contentHeight = secondaryActionFrame.maxY + textSpacing
        }
        
        let rowWidth = contentAreaSize.width - buttonSideInset * 2.0
        
        for i in 0 ..< self.inputNodes.count {
            let inputNode = self.inputNodes[i]
            if i != 0 {
                contentHeight += rowSpacing
            }
            let inputNodeSize = CGSize(width: rowWidth, height: 50.0)
            transition.updateFrame(node: inputNode, frame: CGRect(origin: CGPoint(x: buttonSideInset, y: contentHeight), size: inputNodeSize))
            inputNode.updateLayout(size: inputNodeSize, transition: transition)
            contentHeight += inputNodeSize.height
        }
        
        let minimalBottomInset: CGFloat = 74.0
        let bottomInset = layout.intrinsicInsets.bottom + minimalBottomInset
        
        let buttonWidth = contentAreaSize.width - buttonSideInset * 2.0
        
        let buttonFrame = CGRect(origin: CGPoint(x: floor((contentAreaSize.width - buttonWidth) / 2.0), y: max(contentHeight + buttonSpacing, availableAreaSize.height - bottomInset - buttonHeight)), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        let _ = self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
        
        transition.animateView {
            self.scrollNode.view.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: layout.insets(options: [.input]).bottom + 30.0, right: 0.0)
            self.scrollNode.view.contentSize = CGSize(width: contentAreaSize.width, height: max(availableAreaSize.height, buttonFrame.maxY + bottomInset) - 30.0)
        }
        
        self.updateTitle()
    }
}
