console.log("Hello, My World is here hi hello hello world!");


function add(a, b) {
  return a + b;
}

function divide(a, b) {
  if (b === 0) {
    throw new Error("Cannot divide by zero");
  }
  return a / b;
}

function getDiscountedPrice(price, discountPercent) {
  var total = price - (price * discountPercent);
  return total;
}

console.log("2 + 3 =", add(2, 3));
try {
  console.log("10 / 0 =", divide(10, 0));
} catch (err) {
  console.error("10 / 0 error:", err.message);
}
console.log("Discounted price:", getDiscountedPrice(100, 0.2));
