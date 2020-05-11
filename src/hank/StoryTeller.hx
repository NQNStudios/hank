package hank;

/**
    Due to the design of Hiss, every Hank story needs to be provided a StoryTeller to handle 
    its output and choice callbacks.

    Fortunately, this allows for some cool things, such as a StoryTestCase that implements StoryTeller.
**/
interface StoryTeller {
    public function handleOutput(text: String): Void;
    public function handleChoices(choices: Array<String>): Void;
}