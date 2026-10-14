import '../../config/balance.dart';

/// Food earned from workouts and fed to the pet for XP.
enum PetFood { kibble, steak, feast }

extension PetFoodInfo on PetFood {
  String get label => switch (this) {
    PetFood.kibble => 'Power Kibble',
    PetFood.steak => 'Protein Steak',
    PetFood.feast => 'Golden Feast',
  };

  String get howToEarn => switch (this) {
    PetFood.kibble => 'Every exercise you complete',
    PetFood.steak => 'Full workouts and personal records',
    PetFood.feast => 'Streak milestones, achievements and gym leaders',
  };

  int get xp => switch (this) {
    PetFood.kibble => Balance.kibbleXp,
    PetFood.steak => Balance.steakXp,
    PetFood.feast => Balance.feastXp,
  };

  String get icon => switch (this) {
    PetFood.kibble => 'carrot',
    PetFood.steak => 'steak',
    PetFood.feast => 'fruit-bowl',
  };
}
