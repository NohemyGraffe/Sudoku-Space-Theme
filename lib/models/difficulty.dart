enum Difficulty { easy, medium, hard, expert }

String difficultyLabel(Difficulty d) {
  switch (d) {
    case Difficulty.easy:
      return 'Easy';
    case Difficulty.medium:
      return 'Medium';
    case Difficulty.hard:
      return 'Hard';
    case Difficulty.expert:
      return 'Expert';
  }
}
