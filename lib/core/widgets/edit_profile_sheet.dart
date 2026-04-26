import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import 'app_bottom_sheet.dart';
import 'brand_logo.dart';
import 'custom_button.dart';
import 'custom_textfield.dart';

class EditProfileSheet extends StatefulWidget {
  final String initialName;
  final String initialBio;
  final void Function(String name, String bio) onSave;

  const EditProfileSheet({
    super.key,
    this.initialName = '',
    this.initialBio = '',
    required this.onSave,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _bioController = TextEditingController(text: widget.initialBio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: AppStrings.editProfile,
      child: Column(
        children: [
          const BrandLogo(size: 64),
          const SizedBox(height: 18),
          CustomTextField(
            controller: _nameController,
            placeholder: AppStrings.name,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            prefixIcon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: TextField(
              controller: _bioController,
              maxLines: 3,
              minLines: 3,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: AppStrings.bio,
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          CustomButton(
            label: AppStrings.save,
            onPressed: () {
              widget.onSave(
                _nameController.text.trim(),
                _bioController.text.trim(),
              );
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
