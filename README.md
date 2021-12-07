# 3240-Loop-Unrolling
CMPS 3240 Lab on loop unrolling

## Objectives

* Observe improvement with loop unrolling
* Familiarity with `gcc`'s automatic loop unrolling
* Explicit loop unrolling at the C-level
* Explicit loop unrolling at the x86-level

## Prerequisites

* Basic understanding of loop unrolling

## Requirements

### General 

No general requirements

### Software and OS

This lab is designed for `gcc` version 6.3.0 and Debian version 6.3.0

### Hardware

This lab requires a processor on x86-64 ISA.

## Background

Instruction-level parallelism is a method for parallelism that enables the processor to execute many instructions at once. First, consider a baseline system, a simple pipelined MIPS architecture that has five stages: IF, ID, EXE, MEM and WB. Pipelining allows the processor to accomodate many instructions at once by segmenting the pipeline into many stages. Considering our simple MIPS processor, it enables something like this:

```
IF  ID  EXE MEM WB
    IF  ID  EXE MEM WB
        IF  ID  EXE MEM WB
            IF  ID  EXE MEM WB
                IF  ID  EXE MEM WB
```

With multi-issue processors take that pipeline (which has many stages) and repeat it many times. In practice, this means that pipeline stages can accommodate more than one instruction at once. Considering a two-issue MIPS pipeline, it would like look so:

```
IF  ID  EXE MEM WB
IF  ID  EXE MEM WB
    IF  ID  EXE MEM WB
    IF  ID  EXE MEM WB
        IF  ID  EXE MEM WB
        IF  ID  EXE MEM WB
            IF  ID  EXE MEM WB
            IF  ID  EXE MEM WB
```

And so on. Multi-issue processors fall into one of two categories: static multi-issue and dynamic multi-issue. Modern microprocessors are dynamic-multi issue processors. That is, there are many pipelines in the processor and the processor is responsible for arranging given instructions into issue packets that do not have hazards. Processors may even go so far as to hold back certain instructions and execute them out of order to prevent hazards. The alternative is called static multi-issue processors, where the responsibility for generating issue packets is on the compiler and the coder.

Thus, with current x86 processors, your chip has possibly been executing multiple instructions at once in a given cycle, perhaps without your knowledge. Dynamic multi-issue processors go hand in hand with a technique called instruction level parallelism, or loop unrolling. With knowledge that the processor may have many many pipelines, it makes sense to saturate these pipelines. With loop unrolling, if there is a linear load of work (such as a for loop), repeat the loop body a certain amount of times. This has two benefits:

* Given that the processor is multi-issue, it will saturate unused pipelines, increasing throughput. This is a linear improvement based on the number of times you unroll the loop body, limited by the number of pipes in the processor.
* As a secondary benefit, it will decrease the number of pre- or post-test operations for the loop. E.g., If your loop body is doing two units of work, there are half as many tests to check if you should exit the loop. This reduces the penalty for incorrect guesses during branch speculation. However, due to modern processor's branch table buffer, this will likely be super neglible.

### A simple example

Consider the code in `rolled.c` in this repo. On the departmental server execute the following commands to respectively compile the code and generate assembly code:

```shell
gcc -Wall -O0 -o rolled.out rolled.c
```

This skips our intermediate step of compiling an unlinked binary. When timing this on my local Windows machine using WSL2 Debian I get the following result:

```shell
$ time ./rolled.out
real    0m1.840s
user    0m0.734s
sys     0m1.109s
```

`gcc` has an option to unroll loops and recursive functions automatically for us. The flag is `-funroll-all-loops`, and there are compiler specific pragmas that can provide hints to the compiler for when to attempt to unroll a loop. However, as we have learned throughout the class, the compiler generally does a bad job. When doing the automatic unrolling by the compiler I get:

```shell
$ time ./example1.out
real    0m1.071s
user    0m0.820s
sys     0m0.248s
```

Don't waste time here trying to investigate `-funroll-all-loops`, it's just an example. It's disappointing. There are indeed specific cases where there compiler will help loop unrolling in production, but if you want to optimize a task generally you will need to implement it.

The goal of this lab is to demonstrate that it is indeed possible to observe an improvement in performance if you loop unroll by hand. 

## Unrolling at the C-level

The easiest way to do this is to just cut-and-paste the loop body multiple times in a high-level language. Look at `unroll2.c`.

## Trivia - The sinking of the Itanic

In 1989, HP partnered with Intel to develop a static multi-issue server processor architecture, which they called Explicitly Parallel Instruction Computing (EPIC). Development culiminated in the Intel Itanium architecture (IA64), released in 2001.<sup>1</sup> It was a separate ISA from x86, i.e. x86 code and IA64 code are not compatible. This required developers to ship separate solutions for x86 and IA64. Few IA64 processors were sold, and software availability remained limited. Prolonged, slow development resulted in the Itanium processor being slower than comparable x86 processors of the same generation. It never took off, and the final Itanium chips were released in 2017 with support ending in 2021.<sup>2</sup> Developers gave this processor the nickname Itanic because it was anticipated to sink.3 At the time, AMD and Intel were competing for a way to increment 32-bit x86 processors into the realm of 64-bit. With IA64, Intel bet on static multi-issue, and tried to cause a paradigm shift. As an alternative, AMD provided a backward compatible 64-bit iteration of x86 called AMD64. This was released with their 2003 Opteron CPU. Developers favored the later, most likely due to backward compatability and ease of transitioning to AMD64. Currently AMD-64 is synonymous with x86-64. 

## References

<sup>1</sup>https://en.wikipedia.org/wiki/Itanium

<sup>2</sup>https://arstechnica.com/gadgets/2017/05/intels-itanium-cpus-once-a-play-for-64-bit-servers-and-desktops-are-dead/