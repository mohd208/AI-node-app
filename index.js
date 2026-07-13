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
  if (discountPercent < 0 || discountPercent > 100) {
    throw new Error("discountPercent must be between 0 and 100");
  }
  var total = price - (price * (discountPercent / 100));
  return total;
}

if (require.main === module) {
  console.log("Hello, My World is here hi hello hello world!");
  console.log("2 + 3 =", add(2, 3));
  try {
    console.log("10 / 0 =", divide(10, 0));
  } catch (err) {
    console.error("10 / 0 error:", err.message);
  }
  console.log("Discounted price:", getDiscountedPrice(100, 20));
}

module.exports = { add, divide, getDiscountedPrice };
