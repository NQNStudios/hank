package hank;

import hank.HInterface;

/**
 Runtime interpreter for Hank stories.
**/
class Story {
    var hInterface: HInterface;

    public function new() {
        var variables = [
            'story' => this
        ];
        hInterface = new HInterface(variables);
    }

    /** Parse and run embedded Hank script on the fly. **/
    public function runEmbeddedHank(hank: String) {
        // TODO       
    }
}