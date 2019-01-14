# Writing with Hank

## Introduction

**Hank** is a scripting language built around the idea of marking up pure-text with flow in order to produce interactive scripts. It is based on **ink** by Inkle, which can be found [here](https://www.inklestudios.com/ink/) with source code [here](http://github.com/inkle/ink).

This tutorial is adapted directly from the tutorial for writing **ink**, but explains the ways in which Hank's syntax differs. You can use this tutorial as a guide for porting Ink games to **Hank**.

At its most basic, Hank can be used to write a Choose Your Own-style story, or a branching dialogue tree. But its real strength is in writing dialogues with lots of options and lots of recombination of the flow. 

**Hank** offers several features to enable non-technical writers to branch often, and play out the consequences of those branches, in both minor and major ways, without fuss. 

The script aims to be clean and logically ordered, so branching dialogue can be tested "by eye". The flow is described in a declarative fashion where possible.

It's also designed with redrafting in mind; so editing a flow should be fast.

For a list of new features in **Hank** that aren't found in Ink, see [the last section.](#Extras)



## Extras

### Transcripts and automated testing

