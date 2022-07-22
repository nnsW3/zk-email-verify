pragma circom 2.0.3;

include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "./fp.circom";

// Lifted from MACI https://github.com/privacy-scaling-explorations/maci/blob/v1/circuits/circom/trees/incrementalQuinTree.circom#L29
// Bits is ceil(log2 choices)
template QuinSelector(choices, bits) {
    signal input in[choices];
    signal input index;
    signal output out;

    // Ensure that index < choices
    component lessThan = LessThan(bits);
    lessThan.in[0] <== index;
    lessThan.in[1] <== choices;
    lessThan.out === 1;

    component calcTotal = CalculateTotal(choices);
    component eqs[choices];

    // For each item, check whether its index equals the input index.
    for (var i = 0; i < choices; i ++) {
        eqs[i] = IsEqual();
        eqs[i].in[0] <== i;
        eqs[i].in[1] <== index;

        // eqs[i].out is 1 if the index matches. As such, at most one input to
        // calcTotal is not 0.
        calcTotal.nums[i] <== eqs[i].out * in[i];
    }

    // Returns 0 + 0 + ... + item
    out <== calcTotal.sum;
}

template CalculateTotal(n) {
    signal input nums[n];
    signal output sum;

    signal sums[n];
    sums[0] <== nums[0];

    for (var i=1; i < n; i++) {
        sums[i] <== sums[i - 1] + nums[i];
    }

    sum <== sums[n - 1];
}

// Modulo lifted from https://sourcegraph.com/github.com/darkforest-eth/circuits/-/blob/perlin/perlin.circom and https://sourcegraph.com/github.com/zk-ml/demo/-/blob/circuits/math/circuit.circom
// input: dividend and divisor field elements in [0, sqrt(p))
// output: remainder and quotient field elements in [0, p-1] and [0, sqrt(p)
// Haven't thought about negative divisor yet. Not needed.
// -8 % 5 = 2. [-8 -> 8. 8 % 5 -> 3. 5 - 3 -> 2.]
// (-8 - 2) // 5 = -2
// -8 + 2 * 5 = 2
// check: 2 - 2 * 5 = -8
template Modulo(divisor_bits) {
    signal input dividend; // -8
    signal input divisor; // 5
    signal output remainder; // 2
    signal output quotient; // -2

    component is_neg = IsNegative();
    is_neg.in <== dividend;

    signal output is_dividend_negative;
    is_dividend_negative <== is_neg.out;

    signal output dividend_adjustment;
    dividend_adjustment <== 1 + is_dividend_negative * -2; // 1 or -1

    signal output abs_dividend;
    abs_dividend <== dividend * dividend_adjustment; // 8

    signal output raw_remainder;
    raw_remainder <-- abs_dividend % divisor;

    signal output neg_remainder;
    neg_remainder <-- divisor - raw_remainder;

    if (is_dividend_negative == 1 && raw_remainder != 0) {
        remainder <-- neg_remainder;
    } else {
        remainder <-- raw_remainder;
    }

    quotient <-- (dividend - remainder) / divisor; // (-8 - 2) / 5 = -2.

    dividend === divisor * quotient + remainder; // -8 = 5 * -2 + 2.

    component rp = MultiRangeProof(3, 128);
    rp.in[0] <== divisor;
    rp.in[1] <== quotient;
    rp.in[2] <== dividend;
    //rp.max_abs_value <== SQRT_P;

    // check that 0 <= remainder < divisor
    component remainderUpper = LessThan(divisor_bits);
    remainderUpper.in[0] <== remainder;
    remainderUpper.in[1] <== divisor;
    remainderUpper.out === 1;
}