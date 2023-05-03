# A Compiler (SIMPL to A-PRIMPL)
This compiler was done as two consecutive assignment question of CS 146, W23 offering, instructed by Brad Lushman, at the University of Waterloo. Relevant assignments are [Q9:Compile SIMPL][1] and [Q10:Compile SIMPL-F][2]

[1]: https://github.com/ChunxinZheng/Compiler/issues/1#issue-1693183409
[2]: https://github.com/ChunxinZheng/Compiler/issues/2#issue-1693183617

## Table of Contents

## A simple imperative language: SIMPL

### Motivation
SIMPL is an artificial imperative language, designed by the instructor team of CS 146, that only supports a very small subset of features of imperative programming. To avoid complicated parsing issues and only focus on the core concepts of imperative programming, S-expression syntax is used.
The following are the elements of imperative programming based on which SIMPL is developed:
- Statements that produce no useful value, but get things done through side effects.
- Expressions only as part of statements. (Note since in CS 146 we proceeded into imperative programming from functional programming, namely Racket, distinguishing between statements and expressions are important)
- Sequencing of two or more statements
- Conditional evaluation
- Repetition

### Grammar
Below is the grammar of simplest version of SIMPL, written in Haskell. <br> <br>

program	 	=	 	(vars [(id number) ...] stmt ...) <br> <br>


  stmt = (print aexp)  <br>
 &emsp;&emsp;    | (print string) <br>
 &emsp;&emsp;    | (set id aexp) <br>
 &emsp;&emsp; 	  | (seq stmt ...) <br>
 &emsp;&emsp;     | (iif bexp stmt stmt) <br>
 &emsp;&emsp;     | (skip) <br>
 &emsp;&emsp;	 	  | (while bexp stmt ...) <br> <br>

 aexp	=	(+ aexp aexp) <br>
&emsp;&emsp; 	 	  |	(* aexp aexp) <br>
&emsp;&emsp; 	 	  |	(- aexp aexp) <br>
&emsp;&emsp; 	 	  |	(div aexp aexp) <br>
&emsp;&emsp; 	 	  |	(mod aexp aexp) <br>
&emsp;&emsp; 	 	  |	number <br>
&emsp;&emsp; 	 	  |	id <br> <br>
 	 	 	 	 
 bexp = (= aexp aexp) <br>
&emsp;&emsp; 	 	  | (> aexp aexp) <br>
&emsp;&emsp;	 	   |	(< aexp aexp) <br>
&emsp;&emsp; 	    |	(>= aexp aexp) <br>
&emsp;&emsp; 	    |	(<= aexp aexp) <br>
&emsp;&emsp; 	 	  |	(not bexp) <br>
&emsp;&emsp; 	 	  |	(and bexp ...) <br>
&emsp;&emsp; 	 	  |	(or bexp ...) <br>
&emsp;&emsp; 	 	  |	true <br>
&emsp;&emsp; 	 	  |	false <br> <br>

### SIMPL-F: Supporting Functions
Syntax for defining functions in SIMPL-F: <br>
A program now is a sequence of functions. If there is a main function, that function is applied with no arguments to run the program; otherwise, the program does nothing (pretty much like how C works). <br> <br>
  program	=	function ...  <br> <br>
 	 	 	 	 
  function = (fun (id id ...) (vars [(id int) ...] stmt ...))
 	 	 	 	 
  aexp =	(id aexp ...) <br>
&emsp;&emsp; 	 	|	...
 	 	 	 	 
  stmt = (return aexp) <br>
&emsp;&emsp; 	 	| ...

## The Project
This project is about writing an compiler from SIMPL-F to A-PRIMPL, completed as two consecutive assignment questions of CS 146, W23 offering. For information about the assembly language, A-PRIMPL, and its associated machine language, PRIMPL, please refer to the [assembler project][3]. For convenience, the [assembler](Assembler.rkt) and the [PRIMPL simulator](Simulator.rkt) have also been uploaded to this project. Therefore, the A-PRIMPL code produced by compiler can be further assembled into PRIMPL machine code, and executed by the PRIMPL simulator, if you will. <br>
With regard to the assignment, no starter code has been given except for the [PRIMPL simulator](Simulator.rkt), which was for the use of helping student understand the core of PRIMPL as well as facilitating debugging process. Another helpful resource was the assembler we wrote earlier, we used it along with the PRIMPL simulator for deugging purpose. Considering the difficulty of the assignment, the instructor team has allowed this assignment to be completed in pairs. Both assignments were completed by Chunxin Zheng and Lex Stapleton.

[3]: https://github.com/ChunxinZheng/Pseudo-Assembler.git

## Compiling
### Variables
All variables in the SIMPL code will be substituted with their corresponding locations (more information is stated in the [next section](#stack-frame).
To avoid potential conflicts that may be caused by function names, we will prefix the name of each SIMPL function with an underscore character "_" to dinstinguish them from variables used for compiling.

### Stack Frame
To support recursive calls for functions, we simulate a stack with two pointers, Stack Pointer ```sp``` and Frame Pointer ```fp```. <br>
Each function call will generate a stack frame that contains values for arguements, local variables, and other relative information such as its return address (more detailed information will be stated in the section [Compiling a Function Call](#compiling-a-function-call). <br>
<br>
The ```sp``` stores the address of the first available space in the stack, that is, ```sp``` points to the first available space in the simulated stack. <br>
The ```fp``` points to the first argument for the current function call. <br> 
Both pointers are mutated and dereferenced by basic arithmetics, [move](...), and [offset](...) instructions. <br>
&emsp; E.g. ```(add sp sp 2)``` means to increment the ```sp``` by 2. <br>
&emsp; &emsp; &nbsp; ```(move (0 sp) fp)``` means to store the value stored in ```fp``` to the address where ```sp``` points to. <br>

### Compiling statements within function
Consider: ```(+ exp1 exp2)```. Compiling statement will recursively emit code to compute exp1, then exp2, and finally add. We need to allocate some stack space, and push the first value into stack for storage while compting for the second. After summing these two, we need to pop these two values out of stack so it can be reserved for future use. <br> <br>

The compiler deals with these three as as following:
- push: ```(move (0 sp) N)``` The value N is stored at the top of the stack
- allocate space: ```(add sp sp 1)``` The sp has been incremented once, so the slot at the location  &ensp; ```(0 sp)``` becomes available
- pop: ```(sub sp sp N)``` The top N slots of the stack are freed, the values are popped <br> <br>

For this compiler, the rules for allocating temporary storage when compiling statements go as follows (we will discuss everything about functions in a later part): <br>
1. If the statement will be returning some value, it will push the returning value into the stack, then update the stack pointer.
E.g. compiling ```5``` =>
```racket
     (move (0 sp) 5)
     (add sp sp 1)
```
2. If the statement is an expression, we evaluate sub-expressions respectively, and then combine them at the end <br>
E.g. comping ```(+ exp1 exp2)``` =>
```racket
     compile exp1         ;; the result of exp1 goes to the top of the stack, sp is incremented by 1
     compile exp2         ;; the result of exp2 goes to the top of the stack, sp is incremented by 1 (by 2 in total)
     (sub sp sp 1)
     (add (-1 sp) (-1 sp) (0 sp))   ;; stores the result of (-1 sp)[exp1] adds (0 sp)[exp2] to (-1 sp)
     ;; now the values of [exp1] (is overwritten) and [exp2] (first available "empty" space for the stack) are unrelated
```

#### (set var exp)
```racket
     compile exp         
     (move target (-1 sp)) ;; Normally, [target] is either '_var or the corresponding address
```

#### (iif exp t_stmt f_stmt)
```racket
     ;; In the compiler, unique label names will be generated by appending a counter
     compile exp         
     (sub sp sp 1)                  ;; now (0 sp) stores the result of [exp]
     (branch (0 sp) label_true)     ;; its value is no longer useful after the condition check
     compile f_stmt
     (jump jump_end)
     (label jump_true)
     compile t_stmt
     (label jump_end)
 ```


### Compiling a Function Definition
The number of the function arguments and local variables remains unchanged. Thus we are able to deduce the address of any variable of the function relative to the ```fp```. Therefore, this compiler is designed to have each stack frame initialized as follows: <br>
```racket
fp-> return_ADDR/value    ;; where pc should return to, reused at the end to store the returned value
     return_fp            ;; where fp should return to
     parameters
     locals
sp-> temporary storage   
```
As an example, the function (f x y), with x and y as parameters, in addition with n and m as locals, will have a stack frame initialized as follows: <br>
```racket
fp-> return_ADDR/value    ;; where pc should return to, reused at the end to store the returned value
     return_fp            ;; where fp should return to
     x                    ;; parameters
     y
     n                    ;; locals
     m
sp-> temporary storage   
```

During the first scanning stage of the program, a table (```environment```) that maps each variable to the address in the stack relative to the ```fp``` where the value of such variable may be stored in during a function applicaiton. <br>
<br>
When compiling a function definition, a label with a name that corresponds to the function name is created for any future function calls to jump to. <br>
<br>
The compiled code for evaluating local variables and pushing them into the stack is appended (note that the process of evaluating and pushing the value of arguments will have be done at this point when [applying a function](#compiling-a-function-call)). <br>
The rest of the function definition is compiled as usual statements with all occurrences of variables are replaced by their addresses relative to the ```fp``` based on the previously generated ```environment```.



### Return
Each function produces an integer value through a ```return``` statement. <br>
To guarantee that there is always a returned value for a function, we defined a syntax rule that every function must have a ```return``` statement as its last statement. This rule is checked during the compilation of each function's definition, and the compiler will produces an error if it detects any instances of missing ```return```. <br>
<br>
The compiled code for evaluating the value for ```return``` is generated by the usual arithmetic expression compilation. Note that during our previous compiling process for other statements we push the newly generated value to the top of the stack and incremented the ```sp``` by 1. <br>
We then 
1. store the returning value in ```(-1 fp)```
2. set ```sp``` back to ```fp```
3. move ```fp``` back to where we should return ```fp``` to (this is stored in ```(1 fp)```)
4. jump to where ```PC``` should return to (stored in ```(0 fp)```)
(For how we managed the stack frame to store each relevant information mentioned above please refer to [Compiling a Function Call](#compiling-a-function-call)). <br> 
E.g. (return aexp) ->
```racket
compile aexp
(move (-1 fp) (-1 sp))   ;; (-1 sp) is where we stored the result of compiling aexp
(move sp fp)
(move fp (RETURN_fp fp)) ;; We will compile (const RETURN_fp 1) into the A-PRIMPL program at the beginning 
(jump (RETURN_ADDR sp))  ;; We will compile (const RETURN_ADDR 0) into the A-PRIMPL program at the beginning 

```

### Compiling a Function Call
As described above, besides function arguments and local variables, some other information should also be stored for each funtion call, namely the return, the ```return_fp```, where fp should be reset to, as well as ```return_ADDR```, to which we should reset the PC to. We will handle these along with setting up the parameters while compiling a function call.<br>

<br>
As a result, when compiling a function application, we reserve two spaces to store ```return_ADDR``` and ```return_fp```, and we increment ```sp``` by 2 (so that it points to the first available space again). Then we include the compiled code to evaluating given arguements, and update the ```fp```. Note updating the fp can be a bit tricky due to how this compiler structures the stack frame (please refer to the comments in the code for further detail). <br>
After everything above gets set, we ```jsr``` to the corresponding label while storing the current ```PC``` to the previously reserved space, namely ```(0 fp)```. At this point, everything about the function call is done. As the program runs through the jsr, it will head to the start of the corresponding function definition and start executing the instructions there.<br>
E.g. (f 2 3) ->      (the locals in f are irrelevant)

```racket
(add sp sp 1)
(move (1 sp) fp)     ;; set up RETURN_fp
(add sp sp 2)        ;; (add sp sp 2) since we need to skip RETURN_ADDR as well,
                     ;; we will come back later and set up RETURN_ADDR with jsr
compile 2            ;; we do not move fp at this point since we might still need 
compile 3            ;; to reference variables of current function

(add sp sp 1)        
(add (-1 sp) (* -1 (+ 3 (# of parameters))) sp) ;; tricky part, sp at at this point is
(move fp (-1 sp))                               ;; (# of parameters + 3) ahead of where fp supposed to be
(sub sp sp 1)   

(jsr (0 fp) START_f)
```




