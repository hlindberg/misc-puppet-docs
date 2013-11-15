Expressions
===
L, R, and Non Value Expression
---
A Puppet Program consists of a sequence of Expressions. There are three main kinds of expressions;

* R-value expressions that produce a result (of some type)
* L-value expressions that provide an assignable "slot"
* non-value producing expressions

### L-value Expressions

The L-value expressions are:

* `Variable` when being LHS in an `AssignmentExpression` (operators `=`, `+=`, and `-=`)
* `Name` when being LHS in an `AttributeOperationExpression` (operators `=>`, and `+>` in a
  `ResourceBodyExpression`.
  
<table><tr><th>Note</th></tr>
<tr><td>
  Versions of the Puppet Programming Language before 4x allowed assignment to unassigned slots
  in <code>Array</code> and <code>Hash</code> values - i.e. an <code>AccessExpression</code>
  (e.g. <code>$a[1]</code>) was also an L-value. This is no longer supported - all variables
  and values are strictly immutable.
</td></tr>
</table>

### "Non-Value" Producing Expressions

Non-Value Producing Expressions always produce the special value `undef`. The term "statement" or
"procedure" may also be used to denote such expressions depending on their role.

The following are non-value producing expressions:

* Calls to functions that are marked to be of `statement` kind.
* Collect expressions (operators `<| |>` and `<<| |>>`)
* ClassDefinition
* ResourceTypeDefinition

The result of these expressions are the side effects they have on the state of the compilation.

### R-Value Expressions

All other expressions produce a value.

Literal Value Expressions
---
### Numbers

    # Integers
    10   # decimal
    0777 # octal
    0xFF # hexadecimal
    
    # Floating Point
    0.1
    31.415e-1
    0.31415e1
     
Numbers are tokens produced by the Lexing of the source text. (TODO: REF TO NUMBER LEXING RULES)

Numbers evaluate to themselves.

### Strings

    # Single quoted strings
    'hello'
    'I take a bit
    more room'
    'He said "hello", but it sounded like \'hell-yo\''
    
    # Double quoted strings
    "You can quote me on that"
    "I keep \t of things around here"
    "I can not drink more than $max_beers beers"
    
A single quoted string is a single token produced by the Lexing of the source text (TODO: REF TO
SQ STRING IN LEXING RULES).

A Single Quoted string evaluates to a runtime String type.

A Double Quoted String is a sequence of text string parts, and expression parts. When evaluated
the text parts evaluate to runtime String type, and the expression parts are first evaluated and the result is converted into a runtime String type. The produced value is the concatenation of
all the produced runtime Strings into a single String.

The text parts of a double quoted string are produced by Lexing of the source text (TODO: REF TO
DQ STRING IN LEXING RULES).

Both types of strings can span multiple lines. When they do, the \r\n or \n line endings are
included in the result. There is no unification of line endings.

#### String Interpolation

String interpolation can be performed two different ways:

* $varname - interpolates the result of referencing the variable named 'varname'
* ${expression} - interpolates the result of evaluating the embedded expression.

The expression part has the following rules:

* Any expression may be interpolated (except Non-Value producing expressions such as
  `define` and `class`)
* Automatic conversion to a variable is performed if the expression is on one of the forms:
  * `${<KEYWORD>}` - e.g. `${node}`, `${class}` becomes `${$node}`, `${$class}`
  * `${<QualifiedName>}` - e.g. `${var}` becomes `${$var}`
  * `${<Number>}` - e.g. `${0}` becomes `${$0}`
* Automatic conversion is also performed in these cases but keywords must be written with
  a preceding $:  
  * `${<AccessExpression>}` - e.g. `${var[key]}`, `${var[key][key]}` becomes `${$var[key]}`,
    `${$var[key][key]}`
  * `${<MethodCall>}` - e.g. `${var.each ...}` becomes `${$var.each}`, which also works for the 
    leftmost name in a sequence of method calls e.g. `${var.fee.foo}` becomes `${$var.fee.foo}`  
* **In all other cases a name or number that should be interpreted as a variable must be
  preceded with a `$`**
  * `${if + 1}` - **error**, i.e. not $if + 1
  * `${2 + 2}` - **is 4**, not $0 + 2
  * `${x + 3}` - **error**, is 'x' + 3, not $x + 3 (error because `+` does not operate on `String`)
  * `${if[2]}` - **error**, since `if` is a keyword and the expression is not just the if-name 
    (causes syntax error since an if expression is allowed, but must have correct syntax e.g.
     `${if true { 'always' } else { 'never' }}`

<table><tr><th>Note</th></tr>
<tr><td>
  These rules are different from the rules in Puppet 3x where many constructs did
  not work because of failure to recognize what should <b>not</b> be interpreted 
  as variable reference. Anything but the simplest forms of expression interpolation
  could have surprising effect.
</td></tr>
</table>

The result of the expression is converted to a `String` as specified in the following section.

#### Expression Result to String Conversion

* `undef` is converted to an empty string ''
* `QualifiedName` is converted to the reference in string form
* `QualifiedReference` is converted to string
* `Boolean` is converted to 'true' or 'false' respectively
* A `String` is copied
* A `Numeric` is converted to string using decimal radix (base 10), and uses platform specific
  defaults for conversion of floating points numbers (the result may vary from platform to
  platform)
* Regular Expressions are converted to a regular expression pattern string in transitive form (can
  be converted back to a regular expression again)
* A `Type` is converted to its program source text form
* An `Array` is converted to string by enclosing the contents in `'['` `']'` and then applying the
  conversion rules recursively to each element using `', '` to separate the elements.
* A `Hash` is converted to string by enclosing the contents in `'{'` `'}'` and then applying the
  conversion rules to each element's key and value, producing `<key> '=>' <value>` for each element
  separated by `', '`.
* For `Array` and `Hash`, no trailing comma is produced after the last element.

### Qualified Name

A qualified name evaluates to a string unless it occurs in a context where the name
has specific meaning.

     $a = apache::port # equal to $a = 'apache::port'

### Qualified Reference

A qualified reference evaluates to a Type.

     $a = Integer # a is a reference to the Integer type
     
### Regular Expression

A regular expression pattern evaluates to a runtime regular expression.

     $a = /.*/  # a is a reference to the regular expression
     
Array and Hash Expressions
---
### Array Expression

A "literal" Array has the following syntax:

     LiteralArray: '[' ((Expression (',' Expression)*)? ','?) ']'
     
The expressions are evaluated from left to right, and a runtime array is produced with
the result. 

The Puppet Programming Language '[' token is used in grammatical constructs in a way that
creates an ambiguity. This is resolved by the following rules:

* `[]` as an access operator (getting a 'identified detail' from the LHS) has higher precedence
  than `[]` as a LiteralArray.
* When `[]` appears after a `QualifiedName`, a intermediate whitespace sequence changes the
  lexical meaning of the initial `'['` to mean start of literal array.
* The precedence can be modified by using an expression separator `';'` between the LHS and `'['`.
* A `[]` that appears without a LHS is interpreted as a literal array.

Examples:

     $a = [1, 2, 3] # $a becomes Literal Array of 3 numbers
     $x = $a[1]     # $x becomes 2 (Accessing element at index 1 in the value referenced by $a)
     $x = $a; [1]   # $x becomes the literal array, a literal array containing '1' is the produced
     $x = abc[1]    # $x becomes 'b' (character at index 1 in string 'abc'
     abc [1]        # calls the function abc with the literal array containing '1' as an argument
     
### Hash Expression

A "Literal" Hash has the following syntax.

     LiteralHash: '{' ((HashEntry (',' HashEntry)*)? ','?)) '}'
     HashEntry: Expression '=>' Expression
     
The hash entries are evaluated from left to right, key before value and a runtime hash
object is produced with all of the entries.

Expressions must result in an R-Value.

Operators
---
### + operator
* Performs a concatenate/merge if the LHS is an Array or Hash
* Adds LHS and RHS otherwise
  * LHS and RHS are coerced to Numeric
  * Operation fails if LHS or RHS are not numeric or coercion failed
  
#### Addition

Addition of integer values produces an integer result. If one of the operands is a Float the
result is also a Float. Integral does not overflow.

    1 + 1      # produces 2
    1.0 + 1.0  # produces 2.0

#### Concatenation / Merge

* Concatenates an array or a non array value converted to a single entry array 
  to the end of a new copy of the LHS array.
* If the RHS is a Hash, it is converted to an Array before concatenation (to instead
  concatenate a Hash, use the << operator).
* Merges a Hash by copying the LHS and adding or overwriting keys with the RHS Hash
* If the RHS of a merge is an Array, it is converted to a Hash (the array should be
  on the form `[key, value, key, value, ...]`, or `[[key, value], [key, value], ...]`

Examples

    # LHS must evaluate to an Array or a Hash (or it is a form of arithmetic expression)
    1,2,3] + [4,5,6] => [1,2,3,4,5,6]
    [1,2,3] + 4 => [1,2,3,4]
    [1,2,3] + {a => 10, b => 20} => [1,2,3, [a, 10], [b, 20]]
    {a => 10, b => 20} + {b => 30} => {a => 10, b => 30}
    {a => 10, b => 20} + {c => 30} => {a => 10, b => 30, c => 30}
    {a => 10, b => 20} + 30 => error
    {a => 10, b => 20} + [30] => error
    {a => 10, b => 20} + [c, 30] => {a => 10, b => 20, c => 30}

### - operator

* Performs a delete if the LHS is an Array or Hash
* Subtracts RHS from LHS otherwise
  * LHS and RHS are coerced to Numeric
  * Operation fails if LHS or RHS are not numeric or coercion failed
  
#### Subtraction

Subtraction of integer values produces an integer result. If one of the operands is a Float the
result is also a Float. Integral does not underflow.

    10 - 1     # produces 9
    10.0 - 0.1 # produces 9.9

#### Delete

Deletion produces the LHS \ RHS (set difference).

* Deletes matching entries from the LHS as given by the RHS. A copy of the LHS is first created,
  the original LHS is unchanged. The copy (after deletions) is produced as the result.
* When LHS is an Array, RHS, if not already an array, is transformed to an array and all matching 
  elements are removed (matching is done by equality comparison of each array element).
* When LHS is a Hash;
  * and the RHS is an Array, the entries with keys matching the elements in the array are deleted
  * and the RHS is a Hash, the entries with matching keys are deleted

Examples:
   
    # LHS must evaluate to an Array or a Hash (or it is a form of arithmetic expression)
    [1,2,3,4,5,6] - [4,5,6] => [1,2,3]
    [1,2,3] - 3 => [1,2]
    [1,2,b] - {a => 1, b => 20} => [2]
    {a => 10, b => 20} - {b => 30} => {a => 10}
    {a => 10, b => 20} - a => {b => 20}
    {a => 10, b => 20} - [a,c] => {b => 20}

### unary - operator

* Changes the sign of the operand
  * RHS is coerced to Numeric
  * Operation fails if RHS is not numeric or coercion failed


### * operator

* Multiplies LHS and RHS
  * LHS and RHS are coerced to Numeric
  * Operation fails if LHS or RHS are not numeric or coercion failed

Multiplication of integer values produces an integer result. If one of the operands is a Float the
result is also a Float. Integrals does not overflow.

### / operator

* Divides LHS by RHS
  * LHS and RHS are coerced to Numeric
  * Operation fails if LHS or RHS are not numeric or coercion failed

Division of integer values produces an integer result (without rounding).
If one of the operands is a Float the result is also a Float. Division by 0 is an error.

### % (modulo) operator

* Produces the remainder (modulo) of dividing LHS by RHS
  * LHS and RHS are coerced to Numeric
  * Operation fails if LHS or RHS are not Integer or coercion failed
  
### << operator

* Performs an append if the LHS is an `Array`
* Performs left shift of the LHS by the RHS count of shift steps otherwise
  * LHS and RHS are coerced to Numeric
  * Operation fails if LHS or RHS are not Integer or coercion failed
  * A left shift of a negative count reverses the shift direction

#### Left Shift

Left shift is performed on `Integer` numbers. The LHS is shifted the given amount of bits to the
left. The shift does not overflow.

     1 << 1 # 2
     2 << 2 # 8

#### Append

When the LHS is an `Array`, the RHS is appended to the end of a copy of the LHS, and the result
is produced. The RHS is not converted.

Examples:

     [1,2,3] << 4       # [1,2,3,4]
     [1,2,3] << [4]     # [1,2,3,[4]]
     [1,2,3] << {a=>10} # [1,2,3,{a=>10}]

### >> operator

* Performs right shift of the LHS by the RHS count of shift steps otherwise
  * LHS and RHS are coerced to Numeric
  * Operation fails if LHS or RHS are not Integer or coercion failed
  * A right shift of a negative count reverses the shift direction

Right shift is performed on `Integer` numbers. The LHS is shifted the given amount of bits to the
right. The shift does not overflow. A value smaller than 0 is never produced.

     1 >> 1  # 0
     8 >> 2  # 2
     
### and, or, !, logical operators

The logical connectives `and`, `or` evaluates their LHS and RHS until the truth or falsehood of
the expression is known. Remaining evaluation is skipped.

* The `and` operator produces `true` of both LHS and RHS are "truthy", and `false` otherwise
* The `or` operator produces `true` if either LHS or RHS are "truthy", and `false` otherwise
* The `and` operator has higher precedence than `or`.
* The unary `!` (not) operator reverses its operand, `false` if the operand is "truthy", and `false` 
  otherwise.
* The `!` operator has higher precedence than both `and` and `or`.

Examples:

     true and false  # false
     true or false   # true
     true and 1      # true
     true and ''     # false
     true and !false # true

TODO: REF TO TRUTHY

Comparison Operators
---
### Equality

#### == operator

Tests if LHS is equal to RHS and produces a Boolean.

* If LHS and RHS are coercible to Number, the equality checks is based on numeric value
* If LHS or RHS is coercible to Number, but not the other, the result is false
* String comparison is done case independently.
* If the base type of LHS and RHS is different the result is false
* Arrays are equal if they have the same size and each element is equal (with the semantics of
  == operator)
* Hashes are equal if they have the same size and each element is equal (with the semantics of
  == operator applied to the values).
* Types are equal if they represent the same type
* RegularExpressions are equal if they have identical pattern
* Booleans are equal if they represent the same value - a boolean is not equal to a truthy value
* All other objects are equal if the underlying runtime representation reports them as equal (safety 
  net)
  
Examples

     true == true  # true
     true == ''    # false
     false == ''   # false
     false == !!'' # true

#### =! operator

Tests if the LHS is not equal to RHS and produces a Boolean.

The logical reverse of the == operator. The same as evaluating `!(LHS == RHS)`.

### Pattern Match

#### =~ match operator

Tests if the LHS matches the RHS regular expression, and returns a Boolean result. As a
side effect the variables $0-$n is set with the matches produced.

* If the RHS evaluates to a String a new Regular Expression is crated with the string value
  as its pattern.
* If the RHS is not a Regular Expression (after String conversion) an error is raised.
* If the LHS is not a String an error is raised. (Note, Numeric values are not coerced to
  String automatically because of unknown radix).
  
The numeric variables $0-$n are set as follows:

* $0 represents the entire matched (sub-) string
* $1 represents the first (leftmost) capture group
* $2-$n represents the subsequent capturing groups enumerated from left to right
* Unmatched sections evaluate to undef
* Numeric variables are not visible from outer scopes
* If a match is performed in an inner scope, it will obscure all numerical variables in outer scopes.

The numeric variables are in scope until the end of the block if the match is performed
without introducing a conditional block, and until the end of the conditional constructs if
such a block is introduced.

Example:

    if abc =~ /(a)b(c)/ {
      # $0 == 'abc', $1 == 'a', $2 == 'c'
    }
    elsif {
      # same as above
    }
    else {
      # same as above
    }
    # $0-$n return to the values they had before the if
    
Example:

    $x = abc =~ /(a)b(c)/
    # $0 == 'abc', $1 == 'a', $2 == 'c' (until end of block)

The setting of match variables is also covered per expression that introduces conditional blocks (if,
elsif, case and selector).


#### !~ match operator

Tests if the LHS does not match the RHS and returns a `Boolean` result. This is the same as evaluating `! (LHS =~ RHS)`. The numerical match variables are set as a side effect.

See =~ operator for detail.

### <, >, <=, >=, comparison operators

Comparisons are done by ordering the LHS and RHS as being less than, equal, or greater than.
A comparison operator converts the result to a Boolean.

* `<` true if LHS is less than RHS
* `>` true if LHS is greater than RHS
* `<=` true if LHS is less than or equal to RHS
* `>=` true if LHS is greater than or equal to RHS

* If `<=` is true so is `<` and `==`
* If `>=` is true so is `>` and `==`

#### Comparison Semantics per type

* If both LHS and RHS are coercible to Numeric the comparison is based on the numeric values
* Comparisons of strings is case independent
* All Numeric values are less than all String values
* Only String and Numeric values can be compared

### Assignment Operators

The assignment operators assign the RHS (or an assignment operation involving the RHS) to the L-Value produced by the LHS. A L-value is a name references to a slot in the current scope that can be referenced by a variable.

* A variable produces an L-value name
* Only a simple name is accepted


### = operator

Assigns the evaluated RHS value to the given L-value name. The RHS value is produced as the
result.

### += operator

If the L-value name is a reference to a variable in an outer scope, the evaluated RHS
value is concatenated/merged to the value of the outer scope variable and assigned to the L-value name. If the L-value name is not a reference to an outer scope variable the result is the same as if the regular assignment operator had been used.


* The operation fails if the outer scope value is not an array or a hash, or if the corresponding
  + concatenation operation fails (see '+' Concatenation).
* The produced result is the evaluated RHS

### -= operator

If the L-value name is a reference to a variable in an outer scope, the evaluated RHS
value is deleted from (a copy of) the value of the outer scope variable and assigned to the L-value name. If the L-value name is not a reference to an outer scope variable the value `undef` is assigned (i.e. deleting something from nothing is undefined).

* The operation fails if the outer scope value is not an array or a hash, or if the corresponding
  `-` (deletion) operation fails (see '-' Delete).
* The produced result is the evaluated RHS
