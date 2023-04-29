# Compiler

## SIMPL-F: Supporting Functions

... <br>

### Main Function
A ```main``` function is a function that takes no arguements and is executed when running the program. <br>
A program without a ```main``` function does nothing. Therefore, during the first scanning stage of the program, the compiling process will halt immediately if the ```main``` function is not defined. <br>

### Return
Each function produces an ```integer``` value through a ```return``` statement. <br>
To guarantee that there is always a returned value for a function, we defined a syntax rule that every function must have a ```return``` statement as its last statement. This rule is checked during the first scanning stage of the program, and the compiler will produces an error if it detects any instances of missing ```return```.

### Stack Frame
To support recursive calls for functions, we simulate a stack with two pointers, stack pointer (sp) and frame pointer (fp).

### Compiling a Function Definition

### Conpiling a Function Call
