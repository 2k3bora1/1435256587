import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:chit_fund_flutter/services/utility_service.dart';

class ImagePickerWidget extends StatefulWidget {
  final Uint8List? initialImage;
  final Function(Uint8List?) onImageSelected;
  final String title;
  final bool allowDocument;
  final double height;
  final double width;
  final BoxShape shape;

  const ImagePickerWidget({
    Key? key,
    this.initialImage,
    required this.onImageSelected,
    this.title = 'Select Image',
    this.allowDocument = false,
    this.height = 150,
    this.width = 150,
    this.shape = BoxShape.rectangle,
  }) : super(key: key);

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  Uint8List? _selectedImage;

  @override
  void initState() {
    super.initState();
    _selectedImage = widget.initialImage;
  }

  Future<void> _pickImage(bool fromCamera) async {
    final image = await UtilityService.pickImage(fromCamera: fromCamera);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
      widget.onImageSelected(image);
    }
  }

  Future<void> _pickDocument() async {
    final document = await UtilityService.pickDocument();
    if (document != null) {
      setState(() {
        _selectedImage = document;
      });
      widget.onImageSelected(document);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(false);
                },
              ),
              if (widget.allowDocument)
                ListTile(
                  leading: const Icon(Icons.file_present),
                  title: const Text('Select Document'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickDocument();
                  },
                ),
              if (_selectedImage != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _selectedImage = null;
                    });
                    widget.onImageSelected(null);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showImagePickerOptions,
          child: Container(
            height: widget.height,
            width: widget.width,
            decoration: BoxDecoration(
              shape: widget.shape,
              color: Colors.grey[200],
              border: Border.all(color: Colors.grey),
            ),
            child: _selectedImage != null
                ? widget.shape == BoxShape.circle
                    ? ClipOval(
                        child: Image.memory(
                          _selectedImage!,
                          fit: BoxFit.cover,
                          height: widget.height,
                          width: widget.width,
                        ),
                      )
                    : Image.memory(
                        _selectedImage!,
                        fit: BoxFit.cover,
                      )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.add_a_photo,
                        size: 40,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap to select',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}