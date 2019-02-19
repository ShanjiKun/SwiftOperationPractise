import UIKit

let downloading = ["a", "b", "c"]
let filtering = ["d", "e", "f"]

let visible = Set(["a", "e", "t", "g"])

var allPending = Set(downloading)
allPending.formUnion(filtering)

var cancel = allPending
cancel.subtract(visible)

var start = visible
start.subtract(allPending)

