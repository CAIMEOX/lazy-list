///| A lazy list library providing efficient, on-demand evaluation of list operations.
/// The library supports common list operations like map, filter, fold, etc., but
/// evaluates them lazily, only computing elements when needed.
typealias @lazy.Lazy

///|
typealias @list.List

///|
/// A lazy list type that can be either empty (Nil) or a head element with a lazily
/// evaluated tail (Cons).
pub(all) enum LazyList[T] {
  Nil
  Cons(T, Lazy[LazyList[T]])
}

///|
/// Creates a default empty lazy list for types that implement Default.
pub fn[X] default() -> LazyList[X] {
  Nil
}

///|
/// Converts an immutable List to a LazyList.
pub fn[T] LazyList::from_list(ls : List[T]) -> LazyList[T] {
  loop (ls, Nil) {
    (List::Empty, acc) => acc
    (List::More(x, tail~), acc) =>
      continue (tail, Cons(x, Lazy::from_value(acc)))
  }
}

///|
/// Converts an Array to a LazyList in reverse order.
pub fn[T] LazyList::from_array(ar : Array[T]) -> LazyList[T] {
  loop (ar.length() - 1, Nil) {
    (-1, acc) => acc
    (n, acc) => continue (n - 1, Cons(ar[n], Lazy::from_value(acc)))
  }
}

///|
/// Provides Show implementation for LazyList, converting it to a string representation.
pub impl[T : Show] Show for LazyList[T] with output(self, logger) {
  logger.write_string("[")
  logger.write_string(self.to_array().map(Show::to_string).join(", "))
  logger.write_string("]")
}

///|
/// Provides Eq implementation for LazyList, enabling equality comparison.
pub impl[T : Eq] Eq for LazyList[T] with op_equal(self, other) {
  loop (self, other, true) {
    (_, _, false) => false
    (Nil, Nil, true) => true
    (Cons(x, xs), Cons(y, ys), true) =>
      continue (xs.force(), ys.force(), x == y)
    (_, _, _) => false
  }
}

///|
/// Gets the element at a specific index in the lazy list.
pub fn[T] index(self : LazyList[T], i : Int) -> T {
  match (self, i) {
    (Cons(x, _), 0) => x
    (Nil, _) => abort("index: out of bounds")
    (Cons(_, xs), i) => xs.force().index(i - 1)
  }
}

///|
/// Returns a lazy list of all final segments of the original list.
pub fn[T] tails(self : LazyList[T]) -> LazyList[LazyList[T]] {
  fn go(xs) {
    Cons(
      xs,
      match xs {
        Nil => @lazy.Lazy::from_value(Nil)
        Cons(_, xs1) => @lazy.Lazy::from_thunk(fn() { go(xs1.force()) })
      },
    )
  }

  go(self)
}

///|
/// Concatenates two lazy lists together.
pub fn[T] concat(self : LazyList[T], other : LazyList[T]) -> LazyList[T] {
  match self {
    Nil => other
    Cons(x, xs) =>
      Cons(x, @lazy.Lazy::from_thunk(fn() { xs.force().concat(other) }))
  }
}

///|
/// Provides Add implementation for LazyList using concat operation.
pub impl[T] Add for LazyList[T] with op_add(self, other) {
  self.concat(other)
}

///|
/// Creates an infinite lazy list repeating the same value.
pub fn[T] repeat(val : T) -> LazyList[T] {
  Cons(val, @lazy.Lazy::from_thunk(fn() { repeat(val) }))
}

///|
/// Maps a function over a lazy list.
pub fn[T, U] map(self : LazyList[T], f : (T) -> U) -> LazyList[U] {
  match self {
    Nil => Nil
    Cons(x, xs) =>
      Cons(f(x), @lazy.Lazy::from_thunk(fn() { xs.force().map(f) }))
  }
}

///|
/// Flat maps a function over a lazy list.
pub fn[T, U] flat_map(
  self : LazyList[T],
  f : (T) -> LazyList[U],
) -> LazyList[U] {
  match self {
    Nil => Nil
    Cons(x, xs) => f(x).concat(xs.force().flat_map(f))
  }
}

///|
/// Flattens a lazy list of lazy lists into a single lazy list.
pub fn[T] flatten(self : LazyList[LazyList[T]]) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(h, t) => h.concat(t.force().flatten())
  }
}

///|
/// Splits a lazy list at the given index.
pub fn[T] split_at(self : LazyList[T], i : Int) -> (LazyList[T], LazyList[T]) {
  if i <= 0 {
    (Nil, self)
  } else {
    fn split_at_prime(m, xs) {
      match (m, xs) {
        (_, Nil) => (Nil, Nil)
        (1, Cons(x, xs)) => (Cons(x, Lazy::from_value(Nil)), xs.force())
        (m, Cons(x, xs)) => {
          let (xs1, xs2) = split_at_prime(m - 1, xs.force())
          (Cons(x, xs1 |> Lazy::from_value), xs2)
        }
      }
    }

    split_at_prime(i, self)
  }
}

///|
/// Left fold over a lazy list.
pub fn[T, U] fold_left(self : LazyList[T], f : (U, T) -> U, init~ : U) -> U {
  match self {
    Nil => init
    Cons(x, xs) => xs.force().fold_left(f, init=f(init, x))
  }
}

///|
/// Right fold over a lazy list.
pub fn[T, U] fold_right(self : LazyList[T], f : (T, U) -> U, init~ : U) -> U {
  match self {
    Nil => init
    Cons(y, ys) => f(y, ys.force().fold_right(f, init~))
  }
}

///|
/// Gets the first element of a lazy list.
pub fn[T] head(self : LazyList[T]) -> T {
  match self {
    Cons(x, _) => x
    Nil => abort("head: empty list")
  }
}

///|
/// Gets the tail of a lazy list.
pub fn[T] tail(self : LazyList[T]) -> LazyList[T] {
  match self {
    Cons(_, xs) => xs.force()
    Nil => abort("tail: empty list")
  }
}

///|
/// Computes the length of a lazy list.
pub fn[T] length(self : LazyList[T]) -> Int {
  loop (self, 0) {
    (Nil, l) => l
    (Cons(_, xs), l) => continue (xs.force(), l + 1)
  }
}

///|
/// Applies a function to each element of a lazy list for side effects.
pub fn[T] each(self : LazyList[T], f : (T) -> Unit) -> Unit {
  loop self {
    Nil => ()
    Cons(h, t) => {
      f(h)
      continue t.force()
    }
  }
}

///|
/// Applies a function to each element with its index for side effects.
pub fn[T] eachi(self : LazyList[T], f : (Int, T) -> Unit) -> Unit {
  loop (self, 0) {
    (Nil, _) => ()
    (Cons(x, xs), i) => {
      f(i, x)
      continue (xs.force(), i + 1)
    }
  }
}

///|
/// Sums the elements of a lazy list with an initial value.
pub fn[X : Add] sum(l : LazyList[X], init~ : X) -> X {
  l.fold_left(Add::op_add, init~)
}

///|
/// Zips two lazy lists with a combining function.
pub fn[A, B, C] zip_with(
  self : LazyList[A],
  ys : LazyList[B],
  f : (A, B) -> C,
) -> LazyList[C] {
  match (self, ys) {
    (Cons(x, xs), Cons(y, ys)) =>
      Cons(
        f(x, y),
        Lazy::from_thunk(fn() { xs.force().zip_with(ys.force(), f) }),
      )
    (_, _) => Nil
  }
}

///|
/// Takes elements from a lazy list while they satisfy a predicate.
pub fn[T] take_while(self : LazyList[T], p : (T) -> Bool) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(x, xs) =>
      if p(x) {
        Cons(x, Lazy::from_thunk(fn() { xs.force().take_while(p) }))
      } else {
        Nil
      }
  }
}

///|
/// Takes the first n elements from a lazy list.
pub fn[T] take(self : LazyList[T], n : Int) -> LazyList[T] {
  if n <= 0 {
    Nil
  } else {
    match self {
      Nil => Nil
      Cons(x, xs) => Cons(x, Lazy::from_value(xs.force().take(n - 1)))
    }
  }
}

///|
/// Drops the first n elements from a lazy list.
pub fn[T] drop(self : LazyList[T], n : Int) -> LazyList[T] {
  if n <= 0 {
    self
  } else {
    match self {
      Nil => Nil
      Cons(_, xs) => xs.force().drop(n - 1)
    }
  }
}

///|
/// Drops elements from a lazy list while they satisfy a predicate.
pub fn[T] drop_while(self : LazyList[T], p : (T) -> Bool) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(x, xs) => if p(x) { xs.force().drop_while(p) } else { self }
  }
}

///|
/// Creates an infinite lazy list with arithmetic progression.
pub fn[X : Add] infinite_stream(start : X, step : X) -> LazyList[X] {
  Cons(start, Lazy::from_thunk(fn() { infinite_stream(start + step, step) }))
}

///|
/// Creates an infinite lazy list of natural numbers starting from 0.
pub fn nats() -> LazyList[Int] {
  infinite_stream(0, 1)
}

///|
/// Zips a lazy list with a normal list using a combining function.
pub fn[A, B, C] zip_lazy_normal(
  self : LazyList[A],
  f : (A, B) -> C,
  ys : @list.List[B],
) -> @list.List[C] {
  match (self, ys) {
    (Cons(x, xs), List::More(y, tail~)) =>
      @list.construct(f(x, y), xs.force().zip_lazy_normal(f, tail))
    (_, _) => @list.empty()
  }
}

///|
/// Zips two lazy lists with a combining function, concatenating remaining elements.
pub fn[T] zip_plus(
  f : (T, T) -> T,
  ls1 : LazyList[T],
  ls2 : LazyList[T],
) -> LazyList[T] {
  match (ls1, ls2) {
    (Cons(x, xs), Cons(y, ys)) =>
      Cons(
        f(x, y),
        Lazy::from_thunk(fn() { zip_plus(f, xs.force(), ys.force()) }),
      )
    (xs, ys) => xs.concat(ys)
  }
}

///|
/// Unfolds a lazy list using a generator function.
pub fn[T] unfold(
  self : LazyList[T],
  f : (LazyList[T]) -> (T, LazyList[T])?,
) -> LazyList[T] {
  match f(self) {
    None => Nil
    Some((x, y)) => Cons(x, Lazy::from_thunk(fn() { y.unfold(f) }))
  }
}

///|
/// Filters a lazy list using a predicate.
pub fn[T] filter(self : LazyList[T], pred : (T) -> Bool) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(x, xs) => {
      let xs = xs.force()
      if pred(x) {
        Cons(x, Lazy::from_thunk(fn() { xs.filter(pred) }))
      } else {
        xs.filter(pred)
      }
    }
  }
}

///|
/// Unzips a lazy list of pairs into a pair of lazy lists.
pub fn[T, W] unzip(self : LazyList[(T, W)]) -> (LazyList[T], LazyList[W]) {
  match self {
    Nil => (Nil, Nil)
    Cons((x, y), xs) => {
      let (xs1, xs2) = xs.force().unzip()
      (Cons(x, Lazy::from_value(xs1)), Cons(y, Lazy::from_value(xs2)))
    }
  }
}

///|
/// Converts a lazy list to an array.
pub fn[T] to_array(self : LazyList[T]) -> Array[T] {
  let res = []
  loop self {
    Nil => ()
    Cons(x, xs) => {
      res.push(x)
      continue xs.force()
    }
  }
  res
}
