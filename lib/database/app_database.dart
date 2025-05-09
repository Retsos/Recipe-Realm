import 'dart:async';
import 'package:floor/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'entities.dart';
import 'daos.dart';
import 'migrations.dart';
part 'app_database.g.dart';

@Database(
  version: 10,
  entities: [
    RecipeEntity,
    FavoriteRecipeEntity,
    UserSettingEntity,
    UserProfileEntity,
  ],
)
@TypeConverters([StringListConverter])
abstract class AppDatabase extends FloorDatabase {
  RecipeDao get recipeDao;
  FavoriteRecipeDao get favoriteRecipeDao;
  UserSettingDao get userSettingDao;
  UserProfileDao get userProfileDao;

  static Future<AppDatabase> initialize() async {
    final dbPath = await sqflite.getDatabasesPath();
    final path = '$dbPath/app_database.db';

    print("🔄 Opening or creating database at: $path");

    final database = await $FloorAppDatabase
        .databaseBuilder('app_database.db')
        .addMigrations([
            migration9to10,
        ])
        .build();
      final count = (await database.recipeDao.findAllRecipes()).length;
      if (count == 0) {
        await _seedInitialData(database);
      }
    return database;
  }


  // static Future<void> checkCurrentDatabaseVersion() async {
  //   final dbPath = await sqflite.getDatabasesPath();
  //   final path = '$dbPath/app_database.db';
  //
  //   // Check if database exists
  //   bool exists = await sqflite.databaseExists(path);
  //   if (!exists) {
  //     print("Database doesn't exist yet");
  //     return;
  //   }
  //
  //   // Open the database to check version
  //   final db = await sqflite.openDatabase(path);
  //   int version = await db.getVersion();
  //   print("Current database version: $version");
  //   await db.close();
  // }

  static Future<void> _seedInitialData(AppDatabase database) async {
    print("Starting to seed initial data...");

    try {
      final recipes = await database.recipeDao.findAllRecipes();
      print("Found \${recipes.length} existing recipes");
      if (recipes.isNotEmpty) {
        print("First recipe loaded: \${recipes[0].name}");
      }

      if (recipes.isEmpty) {
        print("No recipes found, seeding default recipes...");

        final defaultRecipes = [
          RecipeEntity(
            documentId: '7W6WY0yQY2oiqMDDdugA',
            name: 'Pizza with ready-made Dough',
            assetPath: 'assets/pizza.png',
            prepTime: '25-30',
            servings: '2-3',
            Introduction: 'A quick and satisfying pizza made with ready-made dough. This recipe combines a rich tomato sauce, creamy mozzarella, crispy bacon, fresh green peppers, and a sprinkle of oregano for an easy yet delicious meal.',
            category: 'Dinner',
            difficulty: 'Easy',
            ingredientsAmount: '6',
            ingredients: [
              'ready made dough',
              'tomato sauce',
              'mozzarella cheese',
              'bacon',
              'oregano',
              'green pepper',
            ],
            instructions: [
              'Preheat your oven to 220°C (428°F).',
              'Spread the tomato sauce evenly over the dough. Sprinkle the shredded mozzarella cheese generously over the sauce. Distribute the cooked, chopped bacon and sliced green pepper evenly on top. Dust the pizza with dried oregano. Optionally, drizzle a little olive oil over the top for extra flavor.',
              'Place the assembled pizza onto a baking sheet or pizza stone. Bake in the preheated oven for 12–15 minutes or until the crust is golden and the cheese is melted and bubbly.',
              'Remove the pizza from the oven, slice it, and serve hot.',
            ],
          ),
          RecipeEntity(
            documentId: 'M2o9qPBq2AYRsATOchsI',
            name: 'Spaghetti Aglio e Olio',
            assetPath: 'assets/spaggeti.png',
            prepTime: '20-30',
            servings: '2-3',
            Introduction: 'An elegant yet simple Italian dish that relies on garlic, olive oil, and a hint of red chili for a burst of flavor, perfect for a quick meal.',
            category: 'Lunch',
            difficulty: 'Easy',
            ingredientsAmount: '8',
            ingredients: [
              '500g spaghetti',
              '80ml olive oil',
              '5-6 clove garlic',
              'parmessan',
              'thyme',
              'pepper',
              'salt',
              'fresh parsley',
            ],
            instructions: [
              'Cook spaghetti in salted boiling water until al dente.',
              'Meanwhile, gently sauté thinly sliced garlic in generous olive oil until light golden.',
              'Serve immediately with a sprinkle of freshly grated Parmesan cheese and some fresh parsley, thyme and pepper.',
            ],
          ),
          RecipeEntity(
            documentId: 'RZ2lAxgb71DImKq9GP2S',
            name: 'Fruit Salad with Honey and Yogurt',
            assetPath: 'assets/fruitsalad.png',
            prepTime: '5-10',
            servings: '1-2',
            Introduction: 'A refreshing and healthy dish perfect for breakfast or a light snack. Fresh fruit is combined with creamy yogurt and a drizzle of honey to create a balanced, energizing treat.',
            category: 'BreakFast',
            difficulty: 'Easy',
            ingredientsAmount: '5',
            ingredients: [
              '1 banana',
              '1 apple',
              '3-4 strawberries',
              '250g of yoghurt',
              '30-40g of honey',
            ],
            instructions: [
              'Wash and chop the fruit into bite-sized pieces. ',
              'In a bowl, combine 1–2 cups of plain Greek yogurt with 1–2 tablespoons of honey (adjust to taste).',
              'Gently toss the chopped fruits with the yogurt-honey mixture until evenly coated.',
              'Refrigerate for 10–15 minutes to allow the flavors to meld. Serve chilled.',
            ],
          ),
          RecipeEntity(
            documentId: 'd1w1yrg9F1A2QK0JVzx8',
            name: 'Scrambled Eggs',
            assetPath: 'assets/scrambledeggs.png',
            prepTime: '10-15',
            servings: '1-2',
            Introduction: 'A quick, nutritious breakfast that offers a creamy, flavorful start to your day.',
            category: 'BreakFast',
            difficulty: 'Easy',
            ingredientsAmount: '8',
            ingredients: [
              '3 eggs',
              '1 pepper',
              'half eggplant',
              'salt',
              '100gr creme cheese',
              'pepper',
              'fresh onion',
              '1 slice of bread',
            ],
            instructions: [
              'In a bowl, whisk together 2–3 eggs.',
              'Heat a non-stick pan with a small knob of butter over medium heat.',
              'Pour in the egg mixture and gently stir continuously until the eggs just set.',
              'Drop in a spoon of creme cheese and continue stiring keeping them soft and creamy.',
              'End it with a bit of fresh onion , salt and pepper.',
              'Serve it on a slice of bread.',
            ],
          ),
          RecipeEntity(
            documentId: 'hYi4kZ9QGB6uw0VoedAd',
            name: 'Crusted cod with vegetables salad',
            assetPath: 'assets/fish.png',
            prepTime: '30-35',
            servings: '3-4',
            Introduction: 'This light and flavorful dish features tender cod fillets paired with roasted vegetables. The natural sweetness of carrots and potatoes blends perfectly with the tang of lemon juice and fresh parsley, all brought together with a drizzle of olive oil for a healthy, satisfying meal.',
            category: 'Dinner',
            difficulty: 'Easy',
            ingredientsAmount: '5',
            ingredients: [
              '1kg cod filleted',
              '2 carrot',
              '4 potatoes',
              '80g olive oil',
              'salt',
              'pepper',
              'fresh parsley',
              '1 onion',
              'lemon juice',
            ],
            instructions: [
              'Preheat your oven to 200°C (390°F).',
              'In a large bowl, combine the sliced carrot, cubed potatoes, and sliced onion.  Drizzle with about half of the olive oil, season with salt and pepper, and toss well.',
              'Spread the vegetables evenly on a baking tray.  Roast in the preheated oven for about 25–30 minutes, or until they are tender and lightly browned, stirring halfway through.',
              'Pat the cod fillets dry with paper towels and season both sides with salt and pepper.  In a large skillet, heat the remaining olive oil over medium-high heat.  Sear the cod fillets for 2–3 minutes on each side until golden and just cooked through (the fish should flake easily with a fork).',
              'Transfer the roasted vegetables to serving plates.  Place the seared cod fillets on top or beside the vegetables.  Drizzle generously with fresh lemon juice and sprinkle with chopped fresh parsley for a bright finish.',
            ],
          ),
          RecipeEntity(
            documentId: 'wdD2iOF0okQY8fB4jTiz',
            name: 'Pork Stir-Fry with Bell Peppers and Rice',
            assetPath: 'assets/pork.png',
            prepTime: '20-30',
            servings: '2-3',
            Introduction: 'This flavorful pork stir-fry combines tender pork with vibrant bell peppers and onions, enhanced by a tangy-sweet sauce featuring balsamic vinegar, mustard, honey, and lemon. Served over rice, this dish brings a perfect balance of savory, sweet, and zesty notes.',
            category: 'Lunch',
            difficulty: 'Medium',
            ingredientsAmount: '14',
            ingredients: [
              '1 onion',
              '1 green pepper',
              '4 table spoon of olive oil',
              '500g pork',
              '1 green pepper',
              'salt',
              'pepper',
              '1 red pepper',
              '1 clove garlic',
              '1 table spoon of honey',
              'oregano',
              '500ml water',
              '50-70g balsamic vinegar',
              '2 table spoon of mustard',
              'lemon juice from 1 lemon',
            ],
            instructions: [
              'Rinse the rice and cook it according to the package instructions. Set aside and keep warm.',
              'In a large skillet or wok, heat the olive oil over medium-high heat.  Add the pork and sear until golden brown on all sides (about 6–8 minutes).  Add the onion and garlic and sauté for another 2–3 minutes until softened.',
              'Toss in the sliced bell peppers and cook for 5–6 minutes until they begin to soften but remain vibrant.',
              'In a small bowl, mix the mustard, honey, lemon juice, balsamic vinegar, oregano, salt, and pepper.  Pour the mixture over the pork and vegetables.  Stir well to coat everything, then reduce heat and simmer for 5–10 minutes, adding a splash of water if needed to loosen the sauce.',
              'Plate the warm rice and spoon the pork stir-fry over it.  Optionally garnish with fresh herbs or extra lemon zest for brightness.',
            ],
          ),
          RecipeEntity(
            documentId: 'zccVaH7s8294bBIIOc2m',
            name: 'Pancakes with honey and fruit',
            assetPath: 'assets/pancakes.png',
            prepTime: '20-30',
            servings: '2-4',
            Introduction: 'Light and fluffy pancakes topped with a vibrant mix of fresh fruits and drizzled with honey—perfect for a refreshing morning treat.',
            category: 'BreakFast',
            difficulty: 'Easy',
            ingredientsAmount: '9',
            ingredients: [
              '1 teaspoon of baking powder',
              '1 cup of flour for all usages',
              '1 tablespoon of soup of sugar',
              '1 tablespoon of soup of olive oil',
              '1/2 teaspoon of vanilla extract',
              '1/2 glass of water',
              '1/2 glass of milk',
              'honey',
              'fruits of your liking',
            ],
            instructions: [
              'In a bowl, combine flour, baking powder, a little sugar, milk, and water until smooth.',
              'Pour small portions of the batter onto a heated non-stick pan to form pancakes.',
              'Cook until bubbles form on the surface, then flip and cook until golden on both sides.',
              'Top with a medley of chopped fresh fruits and drizzle generously with honey before serving.',
            ],
          ),
          RecipeEntity(
            documentId: 'Sf1aNcYRKbkDrNJ5cP3J',
            name: ' Chicken Fillet with Lemon Sauce and Potatoes',
            assetPath: 'assets/chicken.png',
            prepTime: '30-40',
            servings: '3-4',
            Introduction: 'Tender chicken fillets and hearty potatoes are combined in a flavorful dish featuring a tangy lemon sauce enriched with mustard, honey, oregano, and garlic. This dish delivers a perfect balance of savory and zesty notes, ideal for a fulfilling lunch or dinner.',
            category: 'Lunch',
            difficulty: 'Medium',
            ingredientsAmount: '12',
            ingredients: [
              '6 potatoes',
              '4 tablespoon of olive oil',
              'salt',
              'pepper',
              '3-4 cloves garlic',
              'oregano',
              'lemon juice from 2 lemons',
              '200g water',
              '60g mustard',
              '40g honey',
              '500g of chicken fillet',
              '1 onion',
            ],
            instructions: [
              'Chop the onion and mince the garlic.  Peel and cut the potatoes into your desired shape.  Season the chicken fillets generously with salt and pepper.',
              'In a large, deep pan, heat a couple of tablespoons of olive oil over medium heat.  Add the chopped onion and sauté until softened and slightly translucent.  Place the chicken fillets in the pan and cook until lightly browned on both sides.',
              'Add the cut potatoes to the pan with the chicken. Allow them to sauté for a few minutes so they begin to absorb the flavors.',
              'In a small bowl, combine the lemon juice, mustard, honey, dried oregano, and minced garlic. Adjust the quantities according to your taste preference.  Pour this sauce evenly over the chicken and potatoes.',
              'Cover the pan and let everything simmer over medium-low heat for about 20–25 minutes. Check that the chicken is fully cooked and the potatoes are tender.  Taste and adjust the seasoning with additional salt and pepper if needed.',
              'Once cooked, serve the chicken and potatoes hot, drizzling a bit more olive oil on top if desired.',
            ],
          ),
          RecipeEntity(
            documentId: 'WEcy3LPFsvXsKLfSivbW',
            name: 'Summer Risotto',
            assetPath: 'assets/risotto.png',
            prepTime: '20-25',
            servings: '2-3',
            Introduction: 'A comforting, creamy risotto that highlights the earthy flavors of mushrooms and the freshness of zucchini, enriched with Parmesan cheese and a touch of olive oil for a delightful meal.',
            category: 'Dinner',
            difficulty: 'Medium',
            ingredientsAmount: '12',
            ingredients: [
              '2 onions',
              '1 eggplant',
              '1 tablespoon of olive oil',
              'salt',
              'pepper',
              'thyme',
              '2 zucchini',
              '750gr water',
              '300g of tomato',
              '250gr of rice for risotto',
              '1 vegetable cube',
              'Parmesan',
            ],
            instructions: [
              'Finely chop two medium onions. In a large pan, heat one tablespoon of olive oil over medium heat. Add the onion and sauté until soft and translucent.',
              'Add 1 cup of Arborio rice to the pan. Stir continuously for 2 minutes so that the rice is well-coated and lightly toasted.',
              'Warm 4 cups of vegetable broth in a separate pot. Begin adding the broth one ladle at a time to the rice, stirring frequently. Allow the liquid to be absorbed before adding the next ladle.',
              'About halfway through the cooking process (after about 10 minutes), add the sliced eggplant (about 1 cup) and diced zucchini (1 cup). Continue adding broth and stirring.',
              'Once the rice is cooked al dente and the consistency is creamy (approximately 18–20 minutes total), stir in ½ cup of grated Parmesan cheese. Season with salt and pepper to taste.',
              'Drizzle with a little extra olive oil if desired, and serve immediately while hot.',

            ],
          ),
        ];

        for (final recipe in defaultRecipes) {
          try {
            await database.recipeDao.insertRecipe(recipe);
            print("Inserted recipe: \${recipe.name}");
          } catch (e) {
            print("Error inserting recipe \${recipe.name}: \$e");
          }
        }

        final verify = await database.recipeDao.findAllRecipes();
        print("After seeding, found \${verify.length} recipes");
      }
    } catch (e) {
      print("Error seeding recipes: \$e");
    }

    print("Finished seeding initial data");
  }
}

