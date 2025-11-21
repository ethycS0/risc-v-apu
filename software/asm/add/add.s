.section .text
.global _start

_start:
    li x1, 10           
    li x2, 20           
    add x3, x1, x2      

    # Exit
    li x5, 0x80010000   
    li x6, 1            
    sw x6, 0(x5)        

park:
    j park
