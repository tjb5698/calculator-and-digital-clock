Objective
To learn interrupt based multi-tasking programming.

Textbook Reading (for next homework):
MC9S12C128 Family Data Sheet: Chapters 5, 9, and 13
Instruction
Combine the Homework 7 and Homework 8; that is, Write a program to make a calculator and a digital clock displayed on the HyperTerminal connected to the HCS12 board.

The calculator and digital clock rules are:

Input positive decimal numbers only
Input maximum three digit numbers only
Valid operators are: +, -, *, and /
Input number with leading zero is OK
Input only two numbers and one operator in between, no spaces
Show 'Tcalc> 'prompt and echo print user keystrokes unltil Return key
Repeat print user input and print answer after the '=' sign
In case of an invalid input format, repeat print the user input until the error character
In case of an invalid input format, print error message on the next line: 'Invalid input format'
Keep 16bit internal binary number format, detect and flag overflow error
Use integer division and truncate any fraction
12 hour clock
"s" for 'set time' command
Update the time display every second
Fixed time display area on the terminal screen (mid center)
Fixed calculator display area on the terminal screen (top or bottom three lines)
Use Real Time Interrupt feature to keep the time
Set the SCI port Tx and Rx baud rate to 115200 baud for the terminal I/O

The HyperTerminal display should look something like the following:
Tcalc>
Tcalc> 123+4
       123+4=127
Tcalc> 96*15
       96*15=1440
Tcalc> 456@5
       456@
       Invalid input format
Tcalc> 7h4*12
       7h
       Invalid input format
Tcalc> 3*1234
       3*1234
       Invalid input format	;due to 4th digit
Tcalc> 003-678
       003-678=-675
Tcalc> 100+999*2
       100+999*
       Invalid input format
Tcalc> 555/3
       555/3=185
Tcalc> 7*(45+123)
       7*(
       Invalid input format
Tcalc> 78*999
       78*999
       Overflow error
Tcalc> -2*123
       -
       Invalid input format
Tcalc> 73/15
       73/15=4
Tcalc>
Tcalc> s 10:39:59
Tcalc> 
Tcalc> s 05:552:5
       Invalid time format. Correct example => hh:mm:ss
Tcalc> s 05:55:75
       Invalid time format. Correct example => hh:mm:ss
Tcalc> s 12
       Invalid time format. Correct example => hh:mm:ss 
Tcalc>

You MUST set the HyperTerminal to VT100 emulation mode and refer to HW8 information. You may

Clear screen
Enable the scrolling of only top 4 lines (eg. HW8 Sample Program 3)
Calculator input and output on top 4 lines
Digital clock on fixed screen position (eg. below 4th line, center)
Store and recall current cursor position
Back-space (if you like)
There are many other features following the escape sequence

Make your program user friendly by giving simple directions as to how to correctly use your program.

Also, make your program 'fool-proof', never crash or stop based on wrong user response.

You may add other features or decorations.

Procedure for Hyper Terminal to communicate with your board at 115200 baud rate is as follows:

Reset the hcs12 board.
Load hw9 program to hcs12 board.
Run hw9 program on hcs12 board by typing 'go 3100'.
Your hw9 program running on the hcs12 board prints message: 'please change Hyper Terminal to 115.2K baud'.
Your hw9 program running on the hcs12 board changes the baud rate to 115.2K - first clear the SCI Baud Rate Registers and then set them to the right value.
User on the PC Hyper Terminal changes its baud rate to 115.2K by closing the Hyper Terminal and start the new Hyper Terminal with new baud rate.
User on the PC Hyper Terminal hits a return key, your hw9 program running on the hcs12 board prints a prompt 'Tcalc> ', in 115.2K baud.
Continue hw9 program there on - run calculator (foreground) and digital clock (background) program.

Use as many re-usable subroutines as possible, overall program must be small and fit in 4K byte RAM, ending before $3F80

Design the program to start at $3100 and data to start at $3000.