///|
typealias Lazy[T] = @lazy.Lazy[T]

///|
typealias List[T] = @immut/list.T[T]

///|
pub(all) enum LazyList[T] {
  Nil
  Cons(T, Lazy[LazyList[T]])
}

///|
pub fn default[X : Default]() -> LazyList[X] {
  Nil
}

///|
pub fn LazyList::from_list[T](ls : List[T]) -> LazyList[T] {
  loop ls, Nil {
    Nil, acc => acc
    Cons(x, xs), acc => continue xs, Cons(x, Lazy::from_value(acc))
  }
}

///|
pub fn LazyList::from_array[T](ar : Array[T]) -> LazyList[T] {
  loop ar.length() - 1, Nil {
    -1, acc => acc
    n, acc => continue n - 1, Cons(ar[n], Lazy::from_value(acc))
  }
}

///|
pub impl[T : Show] Show for LazyList[T] with output(self, logger) {
  logger.write_string("[")
  logger.write_string(self.to_array().map(Show::to_string).join(", "))
  logger.write_string("]")
}

///|
pub impl[T : Eq] Eq for LazyList[T] with op_equal(self, other) {
  loop self, other, true {
    _, _, false => false
    Nil, Nil, true => true
    Cons(x, xs), Cons(y, ys), true => continue xs.force(), ys.force(), x == y
    _, _, _ => false
  }
}

///|
test "lazy list" {
  let l1 = LazyList::from_array([1, 2, 3, 4, 5, 6])
  let l2 = LazyList::from_array([7, 8, 9, 10, 11])
  inspect!(l1, content="[1, 2, 3, 4, 5, 6]")
  inspect!(l2, content="[7, 8, 9, 10, 11]")
  assert_true!(l1 == l1)
  inspect!(l1.zip_with(l2, Add::op_add), content="[8, 10, 12, 14, 16]")
  inspect!(l1.index(3), content="4")
}

///|
pub fn index[T](self : LazyList[T], i : Int) -> T {
  match (self, i) {
    (Cons(x, _), 0) => x
    (Nil, _) => abort("index: out of bounds")
    (Cons(_, xs), i) => xs.force().index(i - 1)
  }
}

///|
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
pub fn concat[T](self : LazyList[T], other : LazyList[T]) -> LazyList[T] {
  match self {
    Nil => other
    Cons(x, xs) =>
      Cons(x, @lazy.Lazy::from_thunk(fn() { concat(xs.force(), other) }))
  }
}

///|
pub impl[T] Add for LazyList[T] with op_add(self, other) {
  self.concat(other)
}

///|
pub fn repeat[T](val : T) -> LazyList[T] {
  Cons(val, @lazy.Lazy::from_thunk(fn() { repeat(val) }))
}

///|
pub fn map[T, U](self : LazyList[T], f : (T) -> U) -> LazyList[U] {
  match self {
    Nil => Nil
    Cons(x, xs) =>
      Cons(f(x), @lazy.Lazy::from_thunk(fn() { map(xs.force(), f) }))
  }
}

///|
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
pub fn flatten[T](self : LazyList[LazyList[T]]) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(h, t) => h.concat(flatten(t.force()))
  }
}

///|
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
pub fn fold_left[T, U](self : LazyList[T], f : (U, T) -> U, init~ : U) -> U {
  match self {
    Nil => init
    Cons(x, xs) => fold_left(xs.force(), f, init=f(init, x))
  }
}

///|
pub fn fold_right[T, U](self : LazyList[T], f : (T, U) -> U, init~ : U) -> U {
  match self {
    Nil => init
    Cons(y, ys) => f(y, ys.force().fold_right(f, init~))
  }
}

///|
pub fn head[T](self : LazyList[T]) -> T {
  match self {
    Cons(x, _) => x
    Nil => abort("head: empty list")
  }
}

///|
pub fn tail[T](self : LazyList[T]) -> LazyList[T] {
  match self {
    Cons(_, xs) => xs.force()
    Nil => abort("tail: empty list")
  }
}

///|
pub fn length[T](self : LazyList[T]) -> Int {
  loop self, 0 {
    Nil, l => l
    Cons(_, xs), l => continue xs.force(), l + 1
  }
}

///|
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
pub fn sum[X : Add](l : LazyList[X], init~ : X) -> X {
  l.fold_left(Add::op_add, init~)
}

///|
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
pub fn drop_while[T](self : LazyList[T], p : (T) -> Bool) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(x, xs) => if p(x) { drop_while(xs.force(), p) } else { self }
  }
}

///|
pub fn infinite_stream[X : Add](start : X, step : X) -> LazyList[X] {
  Cons(start, Lazy::from_thunk(fn() { infinite_stream(start + step, step) }))
}

///|
pub fn nats() -> LazyList[Int] {
  infinite_stream(0, 1)
}

///|
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

///|
test "lazy" {
  let x = nats()
  inspect!(x.take(10), content="[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]")
  let y = nats().map(fn(x) { x + 10 })
  inspect!(
    y.take(20),
    content="[10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29]",
  )
  let z = x.zip_with(y, Add::op_add)
  inspect!(z.take(10), content="[10, 12, 14, 16, 18, 20, 22, 24, 26, 28]")
  inspect!(
    z.drop(10).take(10),
    content="[30, 32, 34, 36, 38, 40, 42, 44, 46, 48]",
  )
  inspect!(z.head(), content="10")
  inspect!(z.tail().take(5), content="[12, 14, 16, 18, 20]")
}
