/// Optimal Recognition Point: the letter within a word the eye should
/// fixate on to recognize it fastest. Longer words shift the pivot
/// slightly right of center, following the heuristic used by common
/// RSVP readers.
int orpIndexFor(String word) {
  final len = word.length;
  if (len <= 1) return 0;
  if (len <= 5) return 1;
  if (len <= 9) return 2;
  if (len <= 13) return 3;
  return 4;
}
