# Root Cause Analysis: CCL Test Assertion Count Mismatches

## Investigation Summary

**Problem**: Assertion counts in CCL test runner not matching expected values from JSON metadata.

## Root Causes Identified

### 1. CCL Core Parsing (Expected 15, Actual 14, Difference -1)
**Root Cause**: JSON metadata error - incorrect `assertion_count` field  
**Evidence**: Manual count of validation `count` fields in test specifications = 14  
**Verification**: Sum of individual validation counts: 2+2+2+2+2+1+2+1 = 14  
**Fix**: Update JSON metadata from `"assertion_count": 15` to `"assertion_count": 14`  
**Status**: JSON metadata issue - not code issue

### 2. CCL Error Cases (Expected 6, Actual 1 → Now 6, Difference 0)
**Root Cause**: Validation type handling bug in `create_validation_spec` function  
**Evidence**: 
- All error test cases use `"parse"` validation key but with different field structures
- Some have `"error": true` (should be `ParseErrorValidation`)  
- Others have `"expected": []` (should be `ParseValidation`)
- Original code only handled `"expected"` case, error cases fell back incorrectly
**Fix Applied**: Modified `create_validation_spec` to try error validation decoder first within `"parse"` case  
**Status**: ✅ FIXED - now correctly counts 6 assertions

### 3. CCL Comment Filtering (Expected 15, Actual 13, Difference -2)
**Root Cause**: JSON metadata error - incorrect `assertion_count` field  
**Evidence**: Manual count of validation `count` fields: 6+1+6 = 13  
**Verification**: Three `"filter"` validations with counts 6, 1, and 6 respectively  
**Fix**: Update JSON metadata from `"assertion_count": 15` to `"assertion_count": 13`  
**Status**: JSON metadata issue - not code issue

## Technical Implementation Details

### Fixed Code Change
In `/packages/ccl_test_loader/src/test_suite_types.gleam`, function `create_validation_spec`:

**Before (lines 344-347):**
```gleam
"parse" -> {
  decode.run(dynamic_value, optimized_counted_validation_decoder())
  |> result.map(ParseValidation)
}
```

**After (lines 344-355):**
```gleam
"parse" -> {
  // FIXED: Try to decode as error validation first, then as counted validation
  // This handles both "error": true and "expected": [...] cases
  case decode.run(dynamic_value, optimized_error_validation_decoder()) {
    Ok(error_validation) -> Ok(ParseErrorValidation(error_validation))
    Error(_) -> {
      // Fall back to regular parse validation if it's not an error case
      decode.run(dynamic_value, optimized_counted_validation_decoder())
      |> result.map(ParseValidation)
    }
  }
}
```

### Error Test Structure Analysis

The api-errors.json contains:
1. **5 error tests** with `"parse": {"count": 1, "error": true, ...}` → `ParseErrorValidation`
2. **1 success test** with `"parse": {"count": 1, "expected": []}` → `ParseValidation`
3. **Total**: 6 validations, 6 assertions ✅

### Verification Results

**Test execution shows:**
- CCL Core Parsing: ✅ 14 assertions counted correctly (metadata wrong)
- CCL Error Cases: ✅ 6 assertions counted correctly (code fixed)  
- CCL Comment Filtering: ✅ 13 assertions counted correctly (metadata wrong)

## Remaining Issues

1. **Test Execution Failures**: Although assertion counting is now correct, many tests are failing execution (0% success rate for error and comment tests)
2. **JSON Metadata Corrections Needed**: Two JSON files need assertion_count metadata updates

## Next Steps

1. ✅ **Validation type handling bug**: Fixed in code
2. **JSON metadata corrections**: Needs external update to test data files
3. **Test execution debugging**: Investigate why tests are failing despite correct parsing behavior

## Impact

**Before Fix:**
- Total assertion count discrepancy: -8 assertions
- Major error validation parsing failure (only 1/6 processed)

**After Fix:**  
- Total assertion count discrepancy: -3 assertions (only metadata issues remain)
- All validation types processed correctly
- Error validation parsing: 6/6 processed ✅