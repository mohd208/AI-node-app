console.log("Hello, My World is here hi hello hello world!");
console.log("Hello, My World is here hi hello hello world!");


function add(a, b) {
  return a + b;
}

// function divide(a, b) {
//   return a / b;
// }

function getDiscountedPrice(price, discountPercent) {
  var total = price - (price * discountPercent);
  return total;
}

let unusedVar = 42;

console.log("2 + 3 =", add(2, 3));
console.log("10 / 0 =", divide(10, 0));
// console.log("Discounted price:", getDiscountedPrice(100, 0.2));