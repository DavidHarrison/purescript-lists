-- | This module defines a type of _strict_ linked lists, and associated helper
-- | functions and type class instances.
-- |
-- | _Note_: Depending on your use-case, you may prefer to use
-- | `Data.Sequence` instead, which might give better performance for certain
-- | use cases. This module is an improvement over `Data.Array` when working with
-- | immutable lists of data in a purely-functional setting, but does not have
-- | good random-access performance.

module Data.List
  ( List(..)
  , fromList
  , toList

  , singleton
  , (..), range
  , replicate
  , replicateM
  , some
  , many

  , null
  , length

  , (:)
  , snoc
  , insert
  , insertBy

  , head
  , last
  , tail
  , init
  , uncons

  , (!!), index
  , elemIndex
  , elemLastIndex
  , findIndex
  , findLastIndex
  , insertAt
  , deleteAt
  , updateAt
  , modifyAt
  , alterAt

  , reverse
  , concat
  , concatMap
  , filter
  , filterM
  , mapMaybe
  , catMaybes

  , sort
  , sortBy

  , slice
  , take
  , takeWhile
  , drop
  , dropWhile
  , span
  , group
  , group'
  , groupBy

  , nub
  , nubBy
  , union
  , unionBy
  , delete
  , deleteBy
  , (\\)
  , intersect
  , intersectBy

  , zipWith
  , zipWithA
  , zip
  , unzip

  , foldM
  ) where

import Prelude

import Data.Either (Either(..), either)
import Data.Maybe
import Data.Tuple (Tuple(..), fst, snd, uncurry)
import Data.Monoid
import Data.Foldable
import Data.Unfoldable
import Data.Traversable

import Control.Alt
import Control.Lazy
import Control.Plus
import Control.Alternative
import Control.MonadPlus

-- | A strict linked list.
-- |
-- | A list is either empty (represented by the `Nil` constructor) or non-empty, in
-- | which case it consists of a head element, and another list (represented by the
-- | `Cons` constructor).
data List a = Nil | Cons a (List a)

-- | Convert a list into any unfoldable structure.
-- |
-- | Running time: `O(n)`
fromList :: forall f a. (Unfoldable f) => List a -> f a
fromList = unfoldr (\xs -> (\rec -> Tuple rec.head rec.tail) <$> uncons xs)

-- | Construct a list from a foldable structure.
-- |
-- | Running time: `O(n)`
toList :: forall f a. (Foldable f) => f a -> List a
toList = foldr Cons Nil

--------------------------------------------------------------------------------
-- List creation ---------------------------------------------------------------
--------------------------------------------------------------------------------

-- | Create a list with a single element.
-- |
-- | Running time: `O(1)`
singleton :: forall a. a -> List a
singleton a = Cons a Nil

infix 8 ..

-- | An infix synonym for `range`.
(..) :: Int -> Int -> List Int
(..) = range

-- | Create a list containing a range of integers, including both endpoints.
-- |
-- | Running time: `O(n)` where `n` is the difference of the arguments.
range :: Int -> Int -> List Int
range start end | start == end = singleton start
                | otherwise = go end start (if start > end then 1 else -1) Nil
  where
  go s e step tail | s == e = (Cons s tail)
                   | otherwise = go (s + step) e step (Cons s tail)

-- | Create a list with repeated instances of a value.
-- |
-- | Running time: `O(n)` where `n` is the first argument.
replicate :: forall a. Int -> a -> List a
replicate n value = go n Nil
  where
  go n tail | n <= 0 = tail
            | otherwise = go (n - 1) (Cons value tail)

-- | Perform a monadic action `n` times collecting all of the results.
-- |
-- | Running time: Depends on definition of `bind` (`O(n)` for `bind` of O(1))
-- |               where `n` is first argument.
replicateM :: forall m a. (Monad m) => Int -> m a -> m (List a)
replicateM n m | n < one   = return Nil
               | otherwise = do a <- m
                                as <- replicateM (n - one) m
                                return (Cons a as)

-- | Attempt a computation multiple times, requiring at least one success.
-- |
-- | The `Lazy` constraint is used to generate the result lazily, to ensure
-- | termination.
-- | Running time: Depends on usage because of lazy evaluation.
some :: forall f a. (Alternative f, Lazy (f (List a))) => f a -> f (List a)
some v = Cons <$> v <*> defer (\_ -> many v)

-- | Attempt a computation multiple times, returning as many successful results
-- | as possible (possibly zero).
-- |
-- | The `Lazy` constraint is used to generate the result lazily, to ensure
-- | termination.
-- | Running time: Depends on usage because of lazy evaluation.
many :: forall f a. (Alternative f, Lazy (f (List a))) => f a -> f (List a)
many v = some v <|> pure Nil

--------------------------------------------------------------------------------
-- List size -------------------------------------------------------------------
--------------------------------------------------------------------------------

-- | Test whether a list is empty.
-- |
-- | Running time: `O(1)`
null :: forall a. List a -> Boolean
null Nil = true
null _ = false

-- | Get the length of a list
-- |
-- | Running time: `O(n)`
length :: forall a. List a -> Int
length Nil = 0
length (Cons _ xs) = 1 + length xs

--------------------------------------------------------------------------------
-- Extending arrays ------------------------------------------------------------
--------------------------------------------------------------------------------

infixr 6 :

-- | An infix alias for `Cons`; attaches an element to the front of
-- | a list.
-- |
-- | Running time: `O(1)`
(:) :: forall a. a -> List a -> List a
(:) = Cons

-- | Append an element to the end of an array, creating a new array.
-- |
-- | Running time: `O(n)`
snoc :: forall a. List a -> a -> List a
snoc xs x = xs <> singleton x

-- | Insert an element into a sorted list.
-- |
-- | Running time: `O(n)`
insert :: forall a. (Ord a) => a -> List a -> List a
insert = insertBy compare

-- | Insert an element into a sorted list, using the specified function to
-- | determine the ordering of elements.
-- |
-- | Running time: `O(n)`
insertBy :: forall a. (a -> a -> Ordering) -> a -> List a -> List a
insertBy _ x Nil = Cons x Nil
insertBy cmp x ys@(Cons y ys') =
  case cmp x y of
    GT -> Cons y (insertBy cmp x ys')
    _  -> Cons x ys

--------------------------------------------------------------------------------
-- Non-indexed reads -----------------------------------------------------------
--------------------------------------------------------------------------------

-- | Get the first element in a list, or `Nothing` if the list is empty.
-- |
-- | Running time: `O(1)`.
head :: forall a. List a -> Maybe a
head Nil = Nothing
head (Cons x _) = Just x

-- | Get the last element in a list, or `Nothing` if the list is empty.
-- |
-- | Running time: `O(n)`.
last :: forall a. List a -> Maybe a
last = head <<< reverse

-- | Get all but the first element of a list, or `Nothing` if the list is empty.
-- |
-- | Running time: `O(1)`
tail :: forall a. List a -> Maybe (List a)
tail Nil = Nothing
tail (Cons _ xs) = Just xs

-- | Get all but the last element of a list, or `Nothing` if the list is empty.
-- |
-- | Running time: `O(n)`
init :: forall a. List a -> Maybe (List a)
init (Cons x Nil) = Just Nil
init (Cons x xs)  = Cons x <$> init xs
init _            = Nothing

-- | Break a list into its first element, and the remaining elements,
-- | or `Nothing` if the list is empty.
-- |
-- | Running time: `O(1)`
uncons :: forall a. List a -> Maybe { head :: a, tail :: List a }
uncons Nil = Nothing
uncons (Cons x xs) = Just { head: x, tail: xs }

--------------------------------------------------------------------------------
-- Indexed operations ----------------------------------------------------------
--------------------------------------------------------------------------------

-- | Get the element at the specified index, or `Nothing` if the index is out-of-bounds.
-- |
-- | Running time: `O(n)` where `n` is the required index.
index :: forall a. List a -> Int -> Maybe a
index l n = either (Just <<< fst) (const Nothing) $ while iter 0 l
    where iter n' x = if n' == n then Left x else Right (n' + 1)

infixl 8 !!

-- | An infix synonym for `index`.
(!!) :: forall a. List a -> Int -> Maybe a
(!!) = index

-- | Find the index of the first element equal to the specified element.
-- |
-- | Running time: `O(n)`
elemIndex :: forall a. (Eq a) => a -> List a -> Maybe Int
elemIndex x = findIndex (== x)

-- | Find the index of the last element equal to the specified element.
-- |
-- | Running time: `O(n)`
elemLastIndex :: forall a. (Eq a) => a -> List a -> Maybe Int
elemLastIndex x = findLastIndex (== x)

-- | Find the first index for which a predicate holds.
-- |
-- | Running time: `O(n)`
findIndex :: forall a. (a -> Boolean) -> List a -> Maybe Int
findIndex fn = either (Just <<< fst) (const Nothing) <<< while iter 0
  where iter n x = if fn x then Left n else Right (n + 1)

-- | Find the last index for which a predicate holds.
-- |
-- | Running time: `O(n)`
findLastIndex :: forall a. (a -> Boolean) -> List a -> Maybe Int
findLastIndex fn = fst <<< foldl iter (Tuple Nothing 0)
  where iter (Tuple curr n) x = if fn x
                                   then Tuple (Just n) (n + 1)
                                   else Tuple curr     (n + 1)

-- | Insert an element into a list at the specified index, returning a new
-- | list or `Nothing` if the index is out-of-bounds.
-- |
-- | Running time: `O(n)`
insertAt :: forall a. Int -> a -> List a -> Maybe (List a)
insertAt 0 x xs = Just (Cons x xs)
insertAt n x (Cons y ys) = Cons y <$> insertAt (n - 1) x ys
insertAt _ _ _ = Nothing

-- | Delete an element from a list at the specified index, returning a new
-- | list or `Nothing` if the index is out-of-bounds.
-- |
-- | Running time: `O(n)`
deleteAt :: forall a. Int -> List a -> Maybe (List a)
deleteAt n = alterAt n (const Nothing)

-- | Update the element at the specified index, returning a new
-- | list or `Nothing` if the index is out-of-bounds.
-- |
-- | Running time: `O(n)`
updateAt :: forall a. Int -> a -> List a -> Maybe (List a)
updateAt n x = alterAt n (const $ Just x)

-- | Update the element at the specified index by applying a function to
-- | the current value, returning a new list or `Nothing` if the index is
-- | out-of-bounds.
-- |
-- | Running time: `O(n)`
modifyAt :: forall a. Int -> (a -> a) -> List a -> Maybe (List a)
modifyAt n f = alterAt n (Just <<< f)

-- | Update or delete the element at the specified index by applying a
-- | function to the current value, returning a new list or `Nothing` if the
-- | index is out-of-bounds.
-- |
-- | Running time: `O(n)`
alterAt :: forall a. Int -> (a -> Maybe a) -> List a -> Maybe (List a)
alterAt 0 f (Cons y ys) = Just $
  case f y of
    Nothing -> ys
    Just y' -> Cons y' ys
alterAt n f (Cons y ys) = Cons y <$> alterAt (n - 1) f ys
alterAt _ _ _  = Nothing

--------------------------------------------------------------------------------
-- Transformations -------------------------------------------------------------
--------------------------------------------------------------------------------

-- | Reverse a list.
-- |
-- | Running time: `O(n)`
reverse :: forall a. List a -> List a
reverse = foldl (flip Cons) Nil

-- | Flatten a list of lists.
-- |
-- | Running time: `O(n)`, where `n` is the total number of elements.
concat :: forall a. List (List a) -> List a
concat = foldMap id

-- | Apply a function to each element in a list, and flatten the results
-- | into a single, new list.
-- |
-- | Running time: `O(n)`, where `n` is the total number of elements.
concatMap :: forall a b. (a -> List b) -> List a -> List b
concatMap = foldMap

-- | Filter a list, keeping the elements which satisfy a predicate function.
-- |
-- | Running time: `O(n)`
filter :: forall a. (a -> Boolean) -> List a -> List a
filter p = foldMap (\x -> if p x then singleton x else Nil)

-- | Filter where the predicate returns a monadic `Boolean`.
-- |
-- | For example:
-- |
-- | ```purescript
-- | powerSet :: forall a. [a] -> [[a]]
-- | powerSet = filterM (const [true, false])
-- | ```
filterM :: forall a m. (Applicative m) => (a -> m Boolean) -> List a -> m (List a)
filterM _ Nil = return Nil
filterM p (Cons x xs) = consIf <$> p x <*> filterM p xs
  where consIf b xs' = if b then Cons x xs' else xs'

-- | Apply a function to each element in a list, keeping only the results which
-- | contain a value.
-- |
-- | Running time: `O(n)`
mapMaybe :: forall a b. (a -> Maybe b) -> List a -> List b
mapMaybe f = foldMap (maybe Nil singleton <<< f)

-- | Filter a list of optional values, keeping only the elements which contain
-- | a value.
-- |
-- | Running time: `O(n)`
catMaybes :: forall a. List (Maybe a) -> List a
catMaybes = mapMaybe id

--------------------------------------------------------------------------------
-- Sorting ---------------------------------------------------------------------
--------------------------------------------------------------------------------

-- | Sort the elements of an list in increasing order.
sort :: forall a. (Ord a) => List a -> List a
sort xs = sortBy compare xs

-- | Sort the elements of a list in increasing order, where elements are
-- | compared using the specified ordering.
sortBy :: forall a. (a -> a -> Ordering) -> List a -> List a
sortBy cmp = mergeAll <<< sequences
  -- implementation lifted from http://hackage.haskell.org/package/base-4.8.0.0/docs/src/Data-OldList.html#sort
  where
  sequences :: List a -> List (List a)
  sequences (Cons a (Cons b xs))
    | a `cmp` b == GT = descending b (singleton a) xs
    | otherwise = ascending b (Cons a) xs
  sequences xs = singleton xs

  descending :: a -> List a -> List a -> List (List a)
  descending a as (Cons b bs)
    | a `cmp` b == GT = descending b (Cons a as) bs
  descending a as bs = Cons (Cons a as) (sequences bs)

  ascending :: a -> (List a -> List a) -> List a -> List (List a)
  ascending a as (Cons b bs)
    | a `cmp` b /= GT = ascending b (\ys -> as (Cons a ys)) bs
  ascending a as bs = (Cons (as $ singleton a) (sequences bs))

  mergeAll :: List (List a) -> List a
  mergeAll (Cons x Nil) = x
  mergeAll xs = mergeAll (mergePairs xs)

  mergePairs :: List (List a) -> List (List a)
  mergePairs (Cons a (Cons b xs)) = Cons (merge a b) (mergePairs xs)
  mergePairs xs = xs

  merge :: List a -> List a -> List a
  merge as@(Cons a as') bs@(Cons b bs')
    | a `cmp` b == GT = Cons b (merge as bs')
    | otherwise = Cons a (merge as' bs)
  merge Nil bs = bs
  merge as Nil = as

--------------------------------------------------------------------------------
-- Sublists --------------------------------------------------------------------
--------------------------------------------------------------------------------

-- | Extract a sublist by a start and end index.
-- |
-- | Running time: `O(n + m)` where `n` and `m` are the start and end of the
-- |               slice range.
slice :: forall a. Int -> Int -> List a -> List a
slice start end xs = take (end - start) (drop start xs)

-- | Take the specified number of elements from the front of a list.
-- |
-- | Running time: `O(2n)` where `n` is the number of elements to take.
take :: forall a. Int -> List a -> List a
take n = reverse <<< either fst snd <<< while iter (Tuple n Nil)
  where iter (Tuple n l) x = if n <= 0
                                then Left l
                                else Right $ Tuple (n - 1) (Cons x l)

-- | Take those elements from the front of a list which match a predicate.
-- |
-- | Running time (worst case): `O(2n)`
takeWhile :: forall a. (a -> Boolean) -> List a -> List a
takeWhile p = reverse <<< either fst id <<< while iter Nil
  where iter l x = if p x then Right (Cons x l) else Left l

-- | Drop the specified number of elements from the front of a list.
-- |
-- | Running time: `O(n)` where `n` is the number of elements to drop.
drop :: forall a. Int -> List a -> List a
drop n = either (uncurry Cons) (const Nil) <<< while iter n
  where iter n' x = if n' <= 0 then Left x else Right (n' - 1)

-- | Drop those elements from the front of a list which match a predicate.
-- |
-- | Running time (worst case): `O(n)`
dropWhile :: forall a. (a -> Boolean) -> List a -> List a
dropWhile p = either (uncurry Cons) (const Nil) <<< while iter unit
  where iter _ x = if p x then Right unit else Left x

-- | Split a list into two parts:
-- |
-- | 1. the longest initial segment for which all elements satisfy the specified predicate
-- | 2. the remaining elements
-- |
-- | For example,
-- |
-- | ```purescript
-- | span (\n -> n % 2 == 1) (1 : 3 : 2 : 4 : 5 : Nil) == Tuple (1 : 3 : Nil) (2 : 4 : 5 : Nil)
-- | ```
-- |
-- | Running time: `O(n)`
span :: forall a. (a -> Boolean) -> List a -> { init :: List a, rest :: List a }
span p (Cons x xs') | p x = case span p xs' of
  { init: ys, rest: zs } -> { init: Cons x ys, rest: zs }
span _ xs = { init: Nil, rest: xs }

-- | Group equal, consecutive elements of a list into lists.
-- |
-- | For example,
-- |
-- | ```purescript
-- | group (1 : 1 : 2 : 2 : 1 : Nil) == (1 : 1 : Nil) : (2 : 2 : Nil) : (1 : Nil) : Nil
-- | ```
-- |
-- | Running time: `O(n)`
group :: forall a. (Eq a) => List a -> List (List a)
group = groupBy (==)

-- | Sort and then group the elements of a list into lists.
-- |
-- | ```purescript
-- | group' [1,1,2,2,1] == [[1,1,1],[2,2]]
-- | ```
group' :: forall a. (Ord a) => List a -> List (List a)
group' = group <<< sort

-- | Group equal, consecutive elements of a list into lists, using the specified
-- | equivalence relation to determine equality.
-- |
-- | Running time: `O(n)`
groupBy :: forall a. (a -> a -> Boolean) -> List a -> List (List a)
groupBy _ Nil = Nil
groupBy eq (Cons x xs) = case span (eq x) xs of
  { init: ys, rest: zs } -> Cons (Cons x ys) (groupBy eq zs)

--------------------------------------------------------------------------------
-- Set-like operations ---------------------------------------------------------
--------------------------------------------------------------------------------

-- | Remove duplicate elements from a list.
-- |
-- | Running time: `O(n^2)`
nub :: forall a. (Eq a) => List a -> List a
nub = nubBy (==)

-- | Remove duplicate elements from a list, using the specified
-- | function to determine equality of elements.
-- |
-- | Running time: `O(n^2)`
nubBy :: forall a. (a -> a -> Boolean) -> List a -> List a
nubBy _ Nil         = Nil
nubBy f (Cons x xs) = Cons x (nubBy f (filter (\y -> not (f x y)) xs))

-- | Calculate the union of two lists.
-- |
-- | Running time: `O(n^2)`
union :: forall a. (Eq a) => List a -> List a -> List a
union = unionBy (==)

-- | Calculate the union of two lists, using the specified
-- | function to determine equality of elements.
-- |
-- | Running time: `O(n^2)`
unionBy :: forall a. (a -> a -> Boolean) -> List a -> List a -> List a
unionBy eq xs ys = xs <> foldl (flip (deleteBy eq)) (nubBy eq ys) xs

-- | Delete the first occurrence of an element from a list.
-- |
-- | Running time: `O(n)`
delete :: forall a. (Eq a) => a -> List a -> List a
delete = deleteBy (==)

-- | Delete the first occurrence of an element from a list, using the specified
-- | function to determine equality of elements.
-- |
-- | Running time: `O(n)`
deleteBy :: forall a. (a -> a -> Boolean) -> a -> List a -> List a
deleteBy _ _ Nil = Nil
deleteBy f x (Cons y ys) | f x y = ys
deleteBy f x (Cons y ys) = Cons y (deleteBy f x ys)

infix 5 \\

-- | Delete the first occurrence of each element in the second list from the first list.
-- |
-- | Running time: `O(n^2)`
(\\) :: forall a. (Eq a) => List a -> List a -> List a
(\\) = foldl (flip delete)

-- | Calculate the intersection of two lists.
-- |
-- | Running time: `O(n^2)`
intersect :: forall a. (Eq a) => List a -> List a -> List a
intersect = intersectBy (==)

-- | Calculate the intersection of two lists, using the specified
-- | function to determine equality of elements.
-- |
-- | Running time: `O(n^2)`
intersectBy :: forall a. (a -> a -> Boolean) -> List a -> List a -> List a
intersectBy _  Nil _   = Nil
intersectBy _  _   Nil = Nil
intersectBy eq xs  ys  = filter (\x -> any (eq x) ys) xs

--------------------------------------------------------------------------------
-- Zipping ---------------------------------------------------------------------
--------------------------------------------------------------------------------

-- | Apply a function to pairs of elements at the same positions in two lists,
-- | collecting the results in a new list.
-- |
-- | If one list is longer, elements will be discarded from the longer list.
-- |
-- | For example
-- |
-- | ```purescript
-- | zipWith (*) (1 : 2 : 3 : Nil) (4 : 5 : 6 : 7 Nil) == 4 : 10 : 18 : Nil
-- | ```
-- |
-- | Running time: `O(min(m, n))`
zipWith :: forall a b c. (a -> b -> c) -> List a -> List b -> List c
zipWith _ Nil _ = Nil
zipWith _ _ Nil = Nil
zipWith f (Cons a as) (Cons b bs) = Cons (f a b) (zipWith f as bs)

-- | A generalization of `zipWith` which accumulates results in some `Applicative`
-- | functor.
zipWithA :: forall m a b c. (Applicative m) => (a -> b -> m c) -> List a -> List b -> m (List c)
zipWithA f xs ys = sequence (zipWith f xs ys)

-- | Collect pairs of elements at the same positions in two lists.
-- |
-- | Running time: `O(min(m, n))`
zip :: forall a b. List a -> List b -> List (Tuple a b)
zip = zipWith Tuple

-- | Transforms a list of pairs into a list of first components and a list of
-- | second components.
unzip :: forall a b. List (Tuple a b) -> Tuple (List a) (List b)
unzip = foldr (\(Tuple a b) (Tuple as bs) -> Tuple (Cons a as) (Cons b bs)) (Tuple Nil Nil)

--------------------------------------------------------------------------------
-- Folding ---------------------------------------------------------------------
--------------------------------------------------------------------------------

-- | Perform a fold using a monadic step function.
foldM :: forall m a b. (Monad m) => (a -> b -> m a) -> a -> List b -> m a
foldM _ a Nil = return a
foldM f a (Cons b bs) = f a b >>= \a' -> foldM f a' bs

-- | Perform a left fold over a list while the value is a `Right`.
-- | Returns either the `Left` value and the remainder of the list
-- | (potentially Nil) or the find accumulator.
-- |
-- | Running time: worst case `O(n)`
while :: forall a b c. (b -> a -> Either c b) -> b -> List a -> Either (Tuple c (List a)) b
while _ z Nil = Right z
while f z (Cons x xs) = case f z x of
                             Left ret -> Left $ Tuple ret xs
                             Right z' -> while f z' xs

--------------------------------------------------------------------------------
-- Instances -------------------------------------------------------------------
---------------------------------------------------------------------------------

instance showList :: (Show a) => Show (List a) where
  show Nil = "Nil"
  show (Cons x xs) = "Cons (" ++ show x ++ ") (" ++ show xs ++ ")"

instance eqList :: (Eq a) => Eq (List a) where
  eq Nil Nil = true
  eq (Cons x xs) (Cons y ys) = x == y && xs == ys
  eq _ _ = false

instance ordList :: (Ord a) => Ord (List a) where
  compare Nil Nil = EQ
  compare Nil _   = LT
  compare _   Nil = GT
  compare (Cons x xs) (Cons y ys) =
    case compare x y of
      EQ -> compare xs ys
      other -> other

instance semigroupList :: Semigroup (List a) where
  append Nil ys = ys
  append (Cons x xs) ys = Cons x (xs <> ys)

instance monoidList :: Monoid (List a) where
  mempty = Nil

instance functorList :: Functor List where
  map _ Nil = Nil
  map f (Cons x xs) = Cons (f x) (f <$> xs)

instance foldableList :: Foldable List where
  foldr _ b Nil = b
  foldr o b (Cons a as) = a `o` foldr o b as
  foldl _ b Nil = b
  foldl o b (Cons a as) = foldl o (b `o` a) as
  foldMap _ Nil = mempty
  foldMap f (Cons x xs) = f x <> foldMap f xs

instance unfoldableList :: Unfoldable List where
  unfoldr f b = go (f b)
    where
    go Nothing = Nil
    go (Just (Tuple a b)) = Cons a (go (f b))

instance traversableList :: Traversable List where
  traverse _ Nil = pure Nil
  traverse f (Cons a as) = Cons <$> f a <*> traverse f as
  sequence Nil = pure Nil
  sequence (Cons a as) = Cons <$> a <*> sequence as

instance applyList :: Apply List where
  apply Nil _ = Nil
  apply (Cons f fs) xs = (f <$> xs) <> (fs <*> xs)

instance applicativeList :: Applicative List where
  pure a = Cons a Nil

instance bindList :: Bind List where
  bind = flip concatMap

instance monadList :: Monad List

instance altList :: Alt List where
  alt = append

instance plusList :: Plus List where
  empty = Nil

instance alternativeList :: Alternative List

instance monadPlusList :: MonadPlus List
