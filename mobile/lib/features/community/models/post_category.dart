/// SRDS UC8 step 5: "User optionally selects a post category (Milestone,
/// Tip, Question, Motivation)." docs/UI_Design/community 10.png's filter
/// chips: All/Tips/Milestones/Questions/Motivation.
enum PostCategory { milestone, tip, question, motivation }

extension PostCategoryLabel on PostCategory {
  String get label => switch (this) {
    PostCategory.milestone => 'Milestone',
    PostCategory.tip => 'Tip',
    PostCategory.question => 'Question',
    PostCategory.motivation => 'Motivation',
  };
}
