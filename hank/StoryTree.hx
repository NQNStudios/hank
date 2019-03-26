package hank;

import haxe.ds.Option;

@:allow(tests.StoryTreeTest)
class StoryNode {
    public var astIndex(default, null): Int;
    var children: Map<String, StoryNode> = new Map();

    public function new(astIndex: Int) {
        this.astIndex = astIndex;
    }

    public function addChild(name: String, child: StoryNode) {
        this.children[name] = child;
    }

    public function resolve(name: String): Option<StoryNode> {
        if (!children.exists(name)) {
            return None;
        }
        return Some(children[name]);
    }

    public function traverseAll(?nodes: Array<StoryNode>) {
        if (nodes == null) {
            nodes = [];
        }

        nodes.push(this);
        for (c in children) {
            nodes = nodes.concat(c.traverseAll());
        }
        return nodes;
    }

    public function createViewCounts(): Map<StoryNode, Int> {
        var viewCounts = new Map();
        for (node in traverseAll()) {
            viewCounts[node] = 0;
        }
        return viewCounts;
    }

    public static function FromAST(ast: HankAST) {
        var exprIndex = 0;
        var root = new StoryNode(-1);

        var lastKnot = null;
        var lastStitch = null;

        while (exprIndex < ast.length) {
            switch (ast[exprIndex].expr) {
                case EKnot(name):
                    var node = new StoryNode(exprIndex);
                    root.addChild(name, node);
                    lastKnot = node;
                    lastStitch = null;
                case EStitch(name):
                    if (lastKnot == null) {
                        throw 'stitch declared outside of knot';
                    }
                    var node = new StoryNode(exprIndex);
                    lastKnot.addChild(name, node);
                    lastStitch = node;
                case EGather(Some(name), _, _) | EChoice(_, _, Some(name), _, _, _):
                    var node = new StoryNode(exprIndex);
                    if (lastKnot == null) {
                        root.addChild(name, node);
                    } else if (lastStitch == null) {
                        lastKnot.addChild(name, node);
                    } else {
                        lastStitch.addChild(name, node);
                    }
                default:

            }
            exprIndex++;
        }

        return root;
    }
}