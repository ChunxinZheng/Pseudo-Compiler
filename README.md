# Compiler

## SIMPL-F: Supporting Functions

... <br>

### Main Function
A ```main``` function is a function that takes no arguements and is executed when running the program. <br>
A program without a ```main``` function does nothing. Therefore, during the first scanning stage of the program, the compiling process will halt immediately if the ```main``` function is not defined. <br>

### Return
Each function produces an integer value through a ```return``` statement. <br>
To guarantee that there is always a returned value for a function, we defined a syntax rule that every function must have a ```return``` statement as its last statement. This rule is checked during the first scanning stage of the program, and the compiler will produces an error if it detects any instances of missing ```return```.

### Stack Frame
To support recursive calls for functions, we simulate a stack with two pointers, Stack Pointer ```sp``` and Frame Pointer ```fp```. <br>
Each function call will generate a stack frame that contains values for arguements, local variables, and other relative information such as its return address (more detailed information will be stated in the section [Compiling a Function Call](#compiling-a-function-call). <br>
<br>
The ```sp``` stores the address of the first available space in the stack, that is, ```sp``` points to the first available space in the simulated stack. <br>
The ```fp``` points to the first argument for the current function call (more detailed information will be stated in the section [Compiling a Function Call](#compiling-a-function-call). <br> 
Both pointers are mutated and dereferenced by basic arithmetics, [move][...], and [offset][...] instructions. <br>
&emsp; E.g. ```(add sp sp 2)``` means to increment the ```sp``` by 2. <br>
&emsp; &emsp; &nbsp; ```(move (0 sp) fp)``` means to store the value stored in ```fp``` to the address where ```sp``` points to. <br>


### Compiling a Function Definition
When compiling a function definition,  corre


### Compiling a Function Call
