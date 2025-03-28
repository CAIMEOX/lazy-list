///| A lazy list library providing efficient, on-demand evaluation of list operations.
/// The library supports common list operations like map, filter, fold, etc., but
/// evaluates them lazily, only computing elements when needed.
typealias Lazy[T] = @lazy.Lazy[T]

///|
typealias List[T] = @immut/list.T[T]

///|
/// A lazy list type that can be either empty (Nil) or a head element with a lazily
/// evaluated tail (Cons).
pub(all) enum LazyList[T] {
  Nil
  Cons(T, Lazy[LazyList[T]])
}

///|
/// Creates a default empty lazy list for types that implement Default.
pub fn default[X : Default]() -> LazyList[X] {
  Nil
}

///|
/// Converts an immutable List to a LazyList.
pub fn LazyList::from_list[T](ls : List[T]) -> LazyList[T] {
  loop ls, Nil {
    Nil, acc => acc
    Cons(x, xs), acc => continue xs, Cons(x, Lazy::from_value(acc))
  }
}

///|
/// Converts an Array to a LazyList in reverse order.
pub fn LazyList::from_array[T](ar : Array[T]) -> LazyList[T] {
  loop ar.length() - 1, Nil {
    -1, acc => acc
    n, acc => continue n - 1, Cons(ar[n], Lazy::from_value(acc))
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
  loop self, other, true {
    _, _, false => false
    Nil, Nil, true => true
    Cons(x, xs), Cons(y, ys), true => continue xs.force(), ys.force(), x == y
    _, _, _ => false
  }
}

///|
/// Gets the element at a specific index in the lazy list.
pub fn index[T](self : LazyList[T], i : Int) -> T {
  match (self, i) {
    (Cons(x, _), 0) => x
    (Nil, _) => abort("index: out of bounds")
    (Cons(_, xs), i) => xs.force().index(i - 1)
  }
}

///|
/// Returns a lazy list of all final segments of the original list.
pub fn tails[T](self : LazyList[T]) -> LazyList[LazyList[T]] {
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
pub fn concat[T](self : LazyList[T], other : LazyList[T]) -> LazyList[T] {
  match self {
    Nil => other
    Cons(x, xs) =>
      Cons(x, @lazy.Lazy::from_thunk(fn() { concat(xs.force(), other) }))
  }
}

///|
/// Provides Add implementation for LazyList using concat operation.
pub impl[T] Add for LazyList[T] with op_add(self, other) {
  self.concat(other)
}

///|
/// Creates an infinite lazy list repeating the same value.
pub fn repeat[T](val : T) -> LazyList[T] {
  Cons(val, @lazy.Lazy::from_thunk(fn() { repeat(val) }))
}

///|
/// Maps a function over a lazy list.
pub fn map[T, U](self : LazyList[T], f : (T) -> U) -> LazyList[U] {
  match self {
    Nil => Nil
    Cons(x, xs) =>
      Cons(f(x), @lazy.Lazy::from_thunk(fn() { map(xs.force(), f) }))
  }
}

///|
/// Flat maps a function over a lazy list.
pub fn flat_map[T, U](
  self : LazyList[T],
  f : (T) -> LazyList[U]
) -> LazyList[U] {
  match self {
    Nil => Nil
    Cons(x, xs) => f(x).concat(flat_map(xs.force(), f))
  }
}

///|
/// Flattens a lazy list of lazy lists into a single lazy list.
pub fn flatten[T](self : LazyList[LazyList[T]]) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(h, t) => h.concat(flatten(t.force()))
  }
}

///|
/// Splits a lazy list at the given index.
pub fn split_at[T](self : LazyList[T], i : Int) -> (LazyList[T], LazyList[T]) {
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
pub fn fold_left[T, U](self : LazyList[T], f : (U, T) -> U, init~ : U) -> U {
  match self {
    Nil => init
    Cons(x, xs) => fold_left(xs.force(), f, init=f(init, x))
  }
}

///|
/// Right fold over a lazy list.
pub fn fold_right[T, U](self : LazyList[T], f : (T, U) -> U, init~ : U) -> U {
  match self {
    Nil => init
    Cons(y, ys) => f(y, ys.force().fold_right(f, init~))
  }
}

///|
/// Gets the first element of a lazy list.
pub fn head[T](self : LazyList[T]) -> T {
  match self {
    Cons(x, _) => x
    Nil => abort("head: empty list")
  }
}

///|
/// Gets the tail of a lazy list.
pub fn tail[T](self : LazyList[T]) -> LazyList[T] {
  match self {
    Cons(_, xs) => xs.force()
    Nil => abort("tail: empty list")
  }
}

///|
/// Computes the length of a lazy list.
pub fn length[T](self : LazyList[T]) -> Int {
  loop self, 0 {
    Nil, l => l
    Cons(_, xs), l => continue xs.force(), l + 1
  }
}

///|
/// Applies a function to each element of a lazy list for side effects.
pub fn each[T](self : LazyList[T], f : (T) -> Unit) -> Unit {
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
pub fn eachi[T](self : LazyList[T], f : (Int, T) -> Unit) -> Unit {
  loop self, 0 {
    Nil, _ => ()
    Cons(x, xs), i => {
      f(i, x)
      continue xs.force(), i + 1
    }
  }
}

///|
/// Sums the elements of a lazy list with an initial value.
pub fn sum[X : Add](l : LazyList[X], init~ : X) -> X {
  l.fold_left(Add::op_add, init~)
}

///|
/// Zips two lazy lists with a combining function.
pub fn zip_with[A, B, C](
  self : LazyList[A],
  ys : LazyList[B],
  f : (A, B) -> C
) -> LazyList[C] {
  match (self, ys) {
    (Cons(x, xs), Cons(y, ys)) =>
      Cons(
        f(x, y),
        Lazy::from_thunk(fn() { zip_with(xs.force(), ys.force(), f) }),
      )
    (_, _) => Nil
  }
}

///|
/// Takes elements from a lazy list while they satisfy a predicate.
pub fn take_while[T](self : LazyList[T], p : (T) -> Bool) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(x, xs) =>
      if p(x) {
        Cons(x, Lazy::from_thunk(fn() { take_while(xs.force(), p) }))
      } else {
        Nil
      }
  }
}

///|
/// Takes the first n elements from a lazy list.
pub fn take[T](self : LazyList[T], n : Int) -> LazyList[T] {
  if n <= 0 {
    Nil
  } else {
    match self {
      Nil => Nil
      Cons(x, xs) => Cons(x, Lazy::from_value(take(xs.force(), n - 1)))
    }
  }
}

///|
/// Drops the first n elements from a lazy list.
pub fn drop[T](self : LazyList[T], n : Int) -> LazyList[T] {
  if n <= 0 {
    self
  } else {
    match self {
      Nil => Nil
      Cons(_, xs) => drop(xs.force(), n - 1)
    }
  }
}

///|
/// Drops elements from a lazy list while they satisfy a predicate.
pub fn drop_while[T](self : LazyList[T], p : (T) -> Bool) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(x, xs) => if p(x) { drop_while(xs.force(), p) } else { self }
  }
}

///|
/// Creates an infinite lazy list with arithmetic progression.
pub fn infinite_stream[X : Add](start : X, step : X) -> LazyList[X] {
  Cons(start, Lazy::from_thunk(fn() { infinite_stream(start + step, step) }))
}

///|
/// Creates an infinite lazy list of natural numbers starting from 0.
pub fn nats() -> LazyList[Int] {
  infinite_stream(0, 1)
}

///|
/// Zips a lazy list with a normal list using a combining function.
pub fn zip_lazy_normal[A, B, C](
  self : LazyList[A],
  f : (A, B) -> C,
  ys : @immut/list.T[B]
) -> @immut/list.T[C] {
  match (self, ys) {
    (Cons(x, xs), Cons(y, ys)) =>
      Cons(f(x, y), zip_lazy_normal(xs.force(), f, ys))
    (_, _) => Nil
  }
}

///|
/// Zips two lazy lists with a combining function, concatenating remaining elements.
pub fn zip_plus[T](
  f : (T, T) -> T,
  ls1 : LazyList[T],
  ls2 : LazyList[T]
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
pub fn unfold[T](
  self : LazyList[T],
  f : (LazyList[T]) -> (T, LazyList[T])?
) -> LazyList[T] {
  match f(self) {
    None => Nil
    Some((x, y)) => Cons(x, Lazy::from_thunk(fn() { y.unfold(f) }))
  }
}

///|
/// Filters a lazy list using a predicate.
pub fn filter[T](self : LazyList[T], pred : (T) -> Bool) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(x, xs) => {
      let xs = xs.force()
      if pred(x) {
        Cons(x, Lazy::from_thunk(fn() { filter(xs, pred) }))
      } else {
        filter(xs, pred)
      }
    }
  }
}

///|
/// Unzips a lazy list of pairs into a pair of lazy lists.
pub fn unzip[T, W](self : LazyList[(T, W)]) -> (LazyList[T], LazyList[W]) {
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
pub fn to_array[T](self : LazyList[T]) -> Array[T] {
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
