const { add, divide, getDiscountedPrice } = require("./index.js");

console.log("Hello, My World is here hi hello hello world!");
console.log("2 + 3 =", add(2, 3));
try {
  console.log("10 / 0 =", divide(10, 0));
} catch (err) {
  console.error("10 / 0 error:", err.message);
}
console.log("Discounted price:", getDiscountedPrice(100, 20));