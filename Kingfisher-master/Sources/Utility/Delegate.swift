
import Foundation

/// 弱引用,防止循环
class Delegate<Input, Output> {
    init() {}
    
    private var block: ((Input) -> Output?)?
    
    func delegate<T: AnyObject>(on target: T, block: ((T, Input) -> Output)?) {
        self.block = { [weak target] input in  //  弱引用不需要关心循环
            guard let target = target else { return nil }
            return block?(target, input)
        }
    }
    
    func call(_ input: Input) -> Output? {
        return block?(input)
    }
}

extension Delegate where Input == Void {
    func call() -> Output? {
        return call(())
    }
}
