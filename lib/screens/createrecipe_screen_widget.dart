import 'package:reciperealm/screens/login_register_widget.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../widgets/auth_service.dart';

class CreateRecipeScreen extends StatefulWidget {
  const CreateRecipeScreen({Key? key}) : super(key: key);

  @override
  _CreateRecipeScreenState createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _introductionController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _servingsController = TextEditingController();
  final _accessKey = GlobalKey<AccessDropdownState>();
  final _accessOptions = ['private', 'public'];
  final _ingredientsKey = GlobalKey<IngredientsSectionState>();
  final _instructionsKey = GlobalKey<InstructionsSectionState>();
  final _categoryKey = GlobalKey<CategoryDropdownState>();
  final _difficultyKey = GlobalKey<DifficultyDropdownState>();

  final _categories = ['Breakfast', 'Lunch', 'Dinner'];
  final _difficultyLevels = ['Easy', 'Medium', 'Hard'];
  late Future<bool> _internetFuture;

  File? _selectedImage;
  bool _isUploading = false;
  final _picker = ImagePicker();
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _internetFuture = AuthService.hasRealInternet();
  }
  @override
  void dispose() {
    _nameController.dispose();
    _imageUrlController.dispose();
    _introductionController.dispose();
    _prepTimeController.dispose();
    _servingsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _imageUrlController.clear();
      });
    }
  }

  Future<void> _takePhoto() async {
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo != null) {
      setState(() {
        _selectedImage = File(photo.path);
        _imageUrlController.clear();
      });
    }
  }

  Future<String?> _uploadImageToSupabase() async {
    if (_selectedImage == null) {
      return _imageUrlController.text.isNotEmpty ? _imageUrlController.text : null;
    }
    setState(() => _isUploading = true);
    try {
      final uuid = const Uuid().v4();
      final ext = path.extension(_selectedImage!.path);
      final fileName = '$uuid$ext';
      await _supabase.storage.from('reciperealm').upload(
        'public/$fileName',
        _selectedImage!,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      return _supabase.storage.from('reciperealm').getPublicUrl('public/$fileName');
    } catch (e) {
      debugPrint('Upload error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading: $e'), backgroundColor: Colors.red),
      );
      return null;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _submitRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    final imageUrl = await _uploadImageToSupabase();
    if (imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide an image'), backgroundColor: Colors.red),
      );
      return;
    }
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginRegisterPage()),
      );
      return;
    }

    final recipeData = {
      'name': _nameController.text.trim(),
      'image': imageUrl,
      'Introduction': _introductionController.text.trim(),
      'prepTime': _prepTimeController.text.trim(),
      'servings': _servingsController.text.trim(),
      'ingredientsAmount': _ingredientsKey.currentState!.getIngredients().length.toString(),
      'category': _categoryKey.currentState!.selectedCategory ?? '',
      'difficulty': _difficultyKey.currentState!.selectedDifficulty ?? '',
      'ingredients': _ingredientsKey.currentState!.getIngredients(),
      'instructions': _instructionsKey.currentState!.getInstructions(),
      'createdAt': Timestamp.now(),
    };

    try {
      final recipeRef = await FirebaseFirestore.instance
          .collection('Recipe')
          .add({
        ...recipeData,
        'access': _accessKey.currentState!.selectedAccess ?? 'private',
        'createdBy': user.uid,
      });
      final recipeId = recipeRef.id;

      await FirebaseFirestore.instance
          .collection('User')
          .doc(user.uid)
          .update({
        'myrecipes': FieldValue.arrayUnion([recipeId]),
      });

      await FirebaseFirestore.instance
          .collection('User')
          .doc(user.uid)
          .collection('myrecipes')
          .doc(recipeId)
          .set({
        'addedAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe added successfully!'), backgroundColor: Colors.green),
      );
      _clearFields();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _clearFields() {
    _nameController.clear();
    _imageUrlController.clear();
    _introductionController.clear();
    _prepTimeController.clear();
    _servingsController.clear();
    setState(() => _selectedImage = null);
    _ingredientsKey.currentState!.clearFields();
    _instructionsKey.currentState!.clearFields();
    _categoryKey.currentState!.reset();
    _accessKey.currentState!.reset();
    _difficultyKey.currentState!.reset();
  }

  Widget _buildNoInternetWidget() {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: isDark ? Colors.grey[500] : Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No Internet Connection',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              )),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'You need an internet connection to create a recipe.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            onPressed: () {
              setState(() {
                // recreate the future so FutureBuilder will actually call it again
                _internetFuture = AuthService.hasRealInternet();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),

        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<bool>(
      future: _internetFuture,
      builder: (ctx, snap) {
        // 1) Pending
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // 2) No internet or error
        if (snap.hasError || snap.data == false) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Create New Recipe'),
              backgroundColor: Colors.green,
            ),
            body: _buildNoInternetWidget(),
          );
        }

        final theme = Theme.of(context);
        final primary = theme.colorScheme.primary;
        final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

        final user = firebase_auth.FirebaseAuth.instance.currentUser;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Create New Recipe"),
              automaticallyImplyLeading: Navigator.of(context).canPop(),
              foregroundColor: isDarkMode? Colors.black : Colors.white,
              backgroundColor: Colors.green,
              elevation: 0,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 60, color: Colors.grey[500]),
                  const SizedBox(height: 16),
                  Text(
                    "Please sign in to create a new recipe.",
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginRegisterPage()),
                      );
                    },
                    icon: Icon(Icons.login),
                    label: Text("Go to Login"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  )
                ],
              ),
            ),
          );
        }

        final decoration = InputDecoration(
          filled: true,
          fillColor: isDarkMode ? Colors.black26 : Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 2)),
          contentPadding: const EdgeInsets.all(16),
        );

        return Scaffold(
          body: SafeArea(
            child: OrientationBuilder(
              builder: (context, orientation) {
                // Portrait: original scrollable form
                if (orientation == Orientation.portrait) {
                  return CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 220,
                        pinned: true,
                        backgroundColor: Colors.green[700],
                        flexibleSpace: FlexibleSpaceBar(
                          title: Text(
                            'Create New Recipe',
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[300] : Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  offset: const Offset(1.0, 1.0),
                                  blurRadius: 3.0,
                                  color: Colors.black.withAlpha(208),
                                ),
                              ],
                            ),
                          ),
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset('assets/addrecipes.png', fit: BoxFit.cover),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withAlpha(228)],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Basic Info & Image Section
                                const SectionTitle(title: 'Basic Information'),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: decoration.copyWith(
                                      labelText: 'Recipe Name', prefixIcon: Icon(Icons.restaurant_menu, color: primary)),
                                  validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
                                ),
                                const SizedBox(height: 24),
                                const SectionTitle(title: 'Recipe Image'),
                                const SizedBox(height: 12),
                                if (_selectedImage != null)
                                  Container(
                                    height: 200,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover),
                                    ),
                                  )
                                else if (_imageUrlController.text.isNotEmpty)
                                  Container(
                                    height: 200,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(image: NetworkImage(_imageUrlController.text), fit: BoxFit.cover),
                                    ),
                                  )
                                else
                                  Container(
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? Colors.black26 : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: const Center(child: Text('No Image Selected', style: TextStyle(color: Colors.grey))),
                                  ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _isUploading ? null : _pickImage,
                                      icon: const Icon(Icons.photo_library),
                                      label: const Text('Gallery'),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: isDarkMode ? Colors.green[800] : primary, foregroundColor: Colors.white),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _isUploading ? null : _takePhoto,
                                      icon: const Icon(Icons.camera_alt),
                                      label: const Text('Camera'),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: isDarkMode ? Colors.green[800] : primary, foregroundColor: Colors.white),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Expanded(child: Divider()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text('OR', style: TextStyle(color: Colors.grey.shade600)),
                                    ),
                                    const Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _imageUrlController,
                                  decoration: decoration.copyWith(
                                    labelText: 'Image URL',
                                    prefixIcon: Icon(Icons.link, color: primary),
                                    helperText: 'Or enter an image URL directly',
                                  ),
                                  onChanged: (v) {
                                    if (v.isNotEmpty) setState(() => _selectedImage = null);
                                  },
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _introductionController,
                                  decoration: decoration.copyWith(
                                    labelText: 'Introduction',
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.only(bottom: 52),
                                      child: Icon(Icons.description, color: primary),
                                    ),
                                  ),
                                  maxLines: 4,
                                  validator: (v) => v == null || v.isEmpty ? 'Enter intro' : null,
                                ),
                                const SizedBox(height: 24),
                                // Recipe Details
                                const SectionTitle(title: 'Recipe Details'),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _prepTimeController,
                                        decoration: decoration.copyWith(
                                            labelText: 'Prep Time (min)', prefixIcon: Icon(Icons.timer, color: primary)),
                                        keyboardType: TextInputType.number,
                                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _servingsController,
                                        decoration: decoration.copyWith(
                                            labelText: 'Servings', prefixIcon: Icon(Icons.people, color: primary)),
                                        keyboardType: TextInputType.number,
                                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(child: CategoryDropdown(key: _categoryKey, inputDecoration: decoration, primaryColor: primary, categories: _categories)),
                                    const SizedBox(width: 16),
                                    Expanded(child: DifficultyDropdown(key: _difficultyKey, inputDecoration: decoration, primaryColor: primary, difficultyLevels: _difficultyLevels)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                AccessDropdown(key: _accessKey, inputDecoration: decoration, primaryColor: primary, accessOptions: _accessOptions, context: context),
                                const SizedBox(height: 24),
                                // Ingredients & Instructions
                                const SectionTitle(title: 'Ingredients'),
                                const SizedBox(height: 8),
                                IngredientsSection(key: _ingredientsKey, primaryColor: primary),
                                const SizedBox(height: 24),
                                const SectionTitle(title: 'Instructions'),
                                const SizedBox(height: 8),
                                InstructionsSection(key: _instructionsKey, primaryColor: primary),
                                const SizedBox(height: 32),
                                Center(
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 54,
                                    child: ElevatedButton(
                                      onPressed: _isUploading ? null : _submitRecipe,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[700],
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: _isUploading
                                          ? const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(color: Colors.white),
                                          SizedBox(width: 12),
                                          Text('UPLOADING...', style: TextStyle(color: Colors.white)),
                                        ],
                                      )
                                          : const Text('SUBMIT RECIPE', style: TextStyle(color: Colors.white)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Landscape: split form into two columns
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // AppBar replacement for landscape
                        Row(
                          children: [
                            const SizedBox(width: 8),
                            Text('Create New Recipe', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Form(
                          key: _formKey,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SectionTitle(title: 'Basic Information'),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _nameController,
                                      decoration: decoration.copyWith(
                                          labelText: 'Recipe Name', prefixIcon: Icon(Icons.restaurant_menu, color: primary)),
                                      validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
                                    ),
                                    const SizedBox(height: 16),
                                    const SectionTitle(title: 'Recipe Image'),
                                    const SizedBox(height: 12),
                                    if (_selectedImage != null)
                                      Container(
                                        height: 150,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          image: DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover),
                                        ),
                                      )
                                    else if (_imageUrlController.text.isNotEmpty)
                                      Container(
                                        height: 150,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          image: DecorationImage(image: NetworkImage(_imageUrlController.text), fit: BoxFit.cover),
                                        ),
                                      )
                                    else
                                      Container(
                                        height: 150,
                                        decoration: BoxDecoration(
                                          color: isDarkMode ? Colors.black26 : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: const Center(child: Text('No Image Selected', style: TextStyle(color: Colors.grey))),
                                      ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: _isUploading ? null : _pickImage,
                                          icon: const Icon(Icons.photo_library),
                                          label: const Text('Gallery'),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: isDarkMode ? Colors.green[800] : primary, foregroundColor: Colors.white),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: _isUploading ? null : _takePhoto,
                                          icon: const Icon(Icons.camera_alt),
                                          label: const Text('Camera'),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: isDarkMode ? Colors.green[800] : primary, foregroundColor: Colors.white),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _imageUrlController,
                                      decoration: decoration.copyWith(
                                        labelText: 'Image URL',
                                        prefixIcon: Icon(Icons.link, color: primary),
                                        helperText: 'Or enter an image URL directly',
                                      ),
                                      onChanged: (v) {
                                        if (v.isNotEmpty) setState(() => _selectedImage = null);
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                    TextFormField(
                                      controller: _introductionController,
                                      decoration: decoration.copyWith(
                                        labelText: 'Introduction',
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.only(bottom: 52),
                                          child: Icon(Icons.description, color: primary),
                                        ),
                                      ),
                                      maxLines: 4,
                                      validator: (v) => v == null || v.isEmpty ? 'Enter intro' : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Right column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SectionTitle(title: 'Recipe Details'),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _prepTimeController,
                                            decoration: decoration.copyWith(
                                                labelText: 'Prep Time (min)', prefixIcon: Icon(Icons.timer, color: primary)),
                                            keyboardType: TextInputType.number,
                                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _servingsController,
                                            decoration: decoration.copyWith(
                                                labelText: 'Servings', prefixIcon: Icon(Icons.people, color: primary)),
                                            keyboardType: TextInputType.number,
                                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(child: CategoryDropdown(key: _categoryKey, inputDecoration: decoration, primaryColor: primary, categories: _categories)),
                                        const SizedBox(width: 12),
                                        Expanded(child: DifficultyDropdown(key: _difficultyKey, inputDecoration: decoration, primaryColor: primary, difficultyLevels: _difficultyLevels)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    AccessDropdown(key: _accessKey, inputDecoration: decoration, primaryColor: primary, accessOptions: _accessOptions, context: context),
                                    const SizedBox(height: 24),
                                    const SectionTitle(title: 'Ingredients'),
                                    const SizedBox(height: 8),
                                    IngredientsSection(key: _ingredientsKey, primaryColor: primary),
                                    const SizedBox(height: 24),
                                    const SectionTitle(title: 'Instructions'),
                                    const SizedBox(height: 8),
                                    InstructionsSection(key: _instructionsKey, primaryColor: primary),
                                    const SizedBox(height: 32),
                                    Center(
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 54,
                                        child: ElevatedButton(
                                          onPressed: _isUploading ? null : _submitRecipe,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green[700],
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                          child: _isUploading
                                              ? const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              CircularProgressIndicator(color: Colors.white),
                                              SizedBox(width: 12),
                                              Text('UPLOADING...', style: TextStyle(color: Colors.white)),
                                            ],
                                          )
                                              : const Text('SUBMIT RECIPE', style: TextStyle(color: Colors.white)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({Key? key, required this.title}) : super(key: key);
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
  );
}

class CategoryDropdown extends StatefulWidget {
  final InputDecoration inputDecoration;
  final Color primaryColor;
  final List<String> categories;
  const CategoryDropdown({Key? key, required this.inputDecoration, required this.primaryColor, required this.categories}) : super(key: key);
  @override
  CategoryDropdownState createState() => CategoryDropdownState();
}
class CategoryDropdownState extends State<CategoryDropdown> {
  String? selectedCategory;
  void reset() => setState(() => selectedCategory = null);
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: selectedCategory,
    decoration: widget.inputDecoration.copyWith(labelText: 'Category', prefixIcon: Icon(Icons.category, color: widget.primaryColor)),
    items: widget.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
    onChanged: (v) => setState(() => selectedCategory = v),
    validator: (v) => v == null || v.isEmpty ? 'Please select a category' : null,
  );
}

class DifficultyDropdown extends StatefulWidget {
  final InputDecoration inputDecoration;
  final Color primaryColor;
  final List<String> difficultyLevels;
  const DifficultyDropdown({Key? key, required this.inputDecoration, required this.primaryColor, required this.difficultyLevels}) : super(key: key);
  @override
  DifficultyDropdownState createState() => DifficultyDropdownState();
}
class DifficultyDropdownState extends State<DifficultyDropdown> {
  String? selectedDifficulty;
  void reset() => setState(() => selectedDifficulty = null);
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: selectedDifficulty,
    decoration: widget.inputDecoration.copyWith(labelText: 'Difficulty', prefixIcon: Icon(Icons.emoji_objects, color: widget.primaryColor)),
    items: widget.difficultyLevels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
    onChanged: (v) => setState(() => selectedDifficulty = v),
    validator: (v) => v == null || v.isEmpty ? 'Please select difficulty' : null,
  );
}

class IngredientsSection extends StatefulWidget {
  final Color primaryColor;
  const IngredientsSection({Key? key, required this.primaryColor}) : super(key: key);
  @override
  IngredientsSectionState createState() => IngredientsSectionState();
}
class IngredientsSectionState extends State<IngredientsSection> {
  List<TextEditingController> _controllers = [TextEditingController()];
  void add() => setState(() => _controllers.add(TextEditingController()));
  void remove(int i) {
    if (_controllers.length > 1) {
      _controllers[i].dispose();
      setState(() => _controllers.removeAt(i));
    }
  }
  List<String> getIngredients() => _controllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
  void clearFields() {
    for (var c in _controllers) c.dispose();
    setState(() => _controllers = [TextEditingController()]);
  }
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final inputDec = InputDecoration(
      filled: true,
      fillColor: isDarkMode ? Colors.black26 : Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.primaryColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Add all ingredients', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
            ElevatedButton.icon(
              onPressed: add,
              icon: const Icon(Icons.add),
              label: const Text('Add Ingredient'),
              style: ElevatedButton.styleFrom(backgroundColor: isDarkMode ? Colors.green[800] : widget.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _controllers.length,
          itemBuilder: (c, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _controllers[i],
                    decoration: inputDec.copyWith(labelText: 'Ingredient ${i+1}', hintText: 'e.g. 2 cups flour'),
                    validator: i == 0
                        ? (v) => v == null || v.isEmpty ? 'Add at least one ingredient' : null
                        : null,
                  ),
                ),
                IconButton(icon: Icon(Icons.delete_outline, color: Colors.red.shade400), onPressed: () => remove(i)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class InstructionsSection extends StatefulWidget {
  final Color primaryColor;
  const InstructionsSection({Key? key, required this.primaryColor}) : super(key: key);
  @override
  InstructionsSectionState createState() => InstructionsSectionState();
}
class InstructionsSectionState extends State<InstructionsSection> {
  List<TextEditingController> _controllers = [TextEditingController()];
  void add() => setState(() => _controllers.add(TextEditingController()));
  void remove(int i) {
    if (_controllers.length > 1) {
      _controllers[i].dispose();
      setState(() => _controllers.removeAt(i));
    }
  }
  List<String> getInstructions() => _controllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
  void clearFields() {
    for (var c in _controllers) c.dispose();
    setState(() => _controllers = [TextEditingController()]);
  }
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final inputDec = InputDecoration(
      filled: true,
      fillColor: isDarkMode ? Colors.black26 : Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.primaryColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Add step-by-step instructions', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
            ElevatedButton.icon(
              onPressed: add,
              icon: const Icon(Icons.add),
              label: const Text('Add Step'),
              style: ElevatedButton.styleFrom(backgroundColor:isDarkMode ? Colors.green[800] : widget.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _controllers.length,
          itemBuilder: (c, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: widget.primaryColor, shape: BoxShape.circle),
                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _controllers[i],
                    decoration: inputDec.copyWith(labelText: 'Step ${i + 1}', alignLabelWithHint: true),
                    maxLines: 3,
                    validator: i == 0 ? (v) => v == null || v.isEmpty ? 'Add at least one instruction' : null : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: Icon(Icons.delete_outline, color: Colors.red.shade400), onPressed: () => remove(i)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AccessDropdown extends StatefulWidget {
  final InputDecoration inputDecoration;
  final Color primaryColor;
  final List<String> accessOptions;
  final BuildContext context;

  const AccessDropdown({
    Key? key,
    required this.inputDecoration,
    required this.primaryColor,
    required this.accessOptions,
    required this.context,
  }) : super(key: key);

  @override
  AccessDropdownState createState() => AccessDropdownState();
}
class AccessDropdownState extends State<AccessDropdown> {
  String? selectedAccess = 'private'; // Default to private
  bool showWarning = true;

  void reset() => setState(() => selectedAccess = 'private');

  Future<void> _showPublicConfirmationDialog() async {
    return showDialog<void>(
      context: widget.context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final surface = Theme.of(context).colorScheme.surface;
        final onSurface = Theme.of(context).colorScheme.onSurface;
        return AlertDialog(
          title: const Text('Make Recipe Public?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: ListBody(
              children: const <Widget>[
                Text('Are you sure you want to make this recipe public?'),
                SizedBox(height: 12),
                Text('This option cannot be changed later and all users will be able to see your recipe.',
                    style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: onSurface)),
              onPressed: () {
                setState(() {
                  selectedAccess = 'private';
                });
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: surface,
                foregroundColor: onSurface,
              ),
              child: const Text('Yes, Make Public'),
              onPressed: () {
                setState(() {
                  selectedAccess = 'public';
                  showWarning = false; // Don't show warning again this session
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: selectedAccess,
          decoration: widget.inputDecoration.copyWith(
            labelText: 'Access',
            prefixIcon: Icon(Icons.visibility, color: widget.primaryColor),
          ),
          items: widget.accessOptions.map((option) =>
              DropdownMenuItem(
                value: option,
                child: Row(
                  children: [
                    Icon(
                      option == 'private' ? Icons.lock : Icons.public,
                      color: option == 'private' ? Colors.grey : Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      option.substring(0, 1).toUpperCase() + option.substring(1),
                      style: TextStyle(
                        fontWeight: option == 'public' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              )
          ).toList(),
          onChanged: (value) {
            if (value == 'public' && showWarning) {
              _showPublicConfirmationDialog();
            } else {
              setState(() => selectedAccess = value);
            }
          },
          validator: (v) => v == null || v.isEmpty ? 'Please select access type' : null,
        ),
        if (selectedAccess == 'public')
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12.0),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Public recipes can be viewed by all users and cannot be made private later.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}