package hank;

import hiss.HTypes;

/**
    Due to the design of Hiss, every Hank story needs to be provided a StoryTeller to handle 
    its output and choice using callbacks.
**/
interface StoryTeller {
    public function handleOutput(text: String, finished: (Int) -> Void): Void;
    public function handleChoices(choices: Array<String>, choose: (Int) -> Void): Void;
}