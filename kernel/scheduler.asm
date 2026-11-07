; PassOS Scheduler
; PassOS V1.0 is single-tasking. This module provides the cooperative
; scheduler stub and a simple yield mechanism for future multi-task support.

BITS 64

global scheduler_init
global scheduler_yield
global scheduler_run

section .data
    current_task    dq 0
    task_count      dq 0

section .text

scheduler_init:
    mov qword [current_task], 0
    mov qword [task_count], 1
    ret

scheduler_yield:
    ret

scheduler_run:
    ret
