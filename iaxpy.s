#Enrique Tapia
#CS3240
# Dr. Albert Cruz
	.file	"IAXPY.c"
	.text
	.globl	main
	.type	main, @function
main:
.LFB6:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp

	push	%r12	# Save old value of %r12 to the stack
	push	%r13	# Save old value of %r13 to the stack

	.cfi_def_cfa_register 6
	subq	$64, %rsp
	movl	%edi, -52(%rbp)
	movq	%rsi, -64(%rbp)
	movl	$200000000, -8(%rbp)	#const int length 200000000
	movl	$15, -12(%rbp)			#int a 15
	movl	-8(%rbp), %eax
	cltq
	salq	$2, %rax
	movq	%rax, %rdi
	call	malloc@PLT
	movq	%rax, -24(%rbp)			#x
	movl	-8(%rbp), %eax
	cltq
	salq	$2, %rax
	movq	%rax, %rdi
	call	malloc@PLT
	movq	%rax, -32(%rbp)			#y
	movl	-8(%rbp), %eax
	cltq
	salq	$2, %rax
	movq	%rax, %rdi
	call	malloc@PLT
	movq	%rax, -40(%rbp)			#result
	movl	$0, -4(%rbp)
	jmp	.L2
.L3:
	movl	-4(%rbp), %eax			#Reload i
	cltq							#Promote eax to rax
	leaq	0(,%rax,4), %rdx		#4 * i (bytes)
	movq	-24(%rbp), %rax			#x
	addq	%rdx, %rax				#x[i]
	leaq	4(%rax), %r12#<-2		#x[i+1]
	movl	(%rax), %eax#<-1

#Multiply a * x[i] & a *x[i+1]
	imull	-12(%rbp), %eax			#a * x[i]
	movl	%eax, %ebx#<--1
	movl	(%r12), %ecx
	imull	-12(%rbp), %ecx	#<--2	#a * x[i+1]

	movl	-4(%rbp), %eax			#Reload i
	cltq							#Promote eax to rdx
	leaq	0(,%rax,4), %rdx		#4 * i (bytes)
	movq	-32(%rbp), %rax			#y
	addq	%rdx, %rax				#y[i]
	movl	(%rax), %edx#<---1
	leaq	4(%rax), %r13#<---2		#y[i+1]

#addition 
	addl	%ebx, %edx#<----1		#(a * x[i]) + (y[i])
	movl	(%r13), %eax
	addl	%eax, %ecx#<----2		#(a * x[i+1]) + (y[i+1])

	movl	-4(%rbp), %eax			#Reload i
	cltq							#Promote eax to rsi
	leaq	0(,%rax,4), %rsi		#4 * i (bytes)
	movq	-40(%rbp), %rax			#result
	addq	%rsi, %rax				#result[i]
	
	movl	%edx, (%rax)			#stores (a * x[i]) + (y[i]) --> result[i]
	movl	%ecx, 4(%rax)			#stores (a * x[i+1]) + (y[i+1]) -->result[i+1]
	addl	$2, -4(%rbp)			#increment by 2
.L2:
	movl	-4(%rbp), %eax
	cmpl	-8(%rbp), %eax
	jl	.L3
	movq	-24(%rbp), %rax
	movq	%rax, %rdi
	call	free@PLT
	movq	-32(%rbp), %rax
	movq	%rax, %rdi
	call	free@PLT
	movq	-40(%rbp), %rax
	movq	%rax, %rdi
	call	free@PLT
	movl	$1, %eax
	pop		%r13
	pop		%r12
	leave
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE6:
	.size	main, .-main
	.ident	"GCC: (Debian 8.3.0-6) 8.3.0"
	.section	.note.GNU-stack,"",@progbits
