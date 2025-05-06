import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class SkillItem extends StatelessWidget {
  final String skillName;
  final String level;
  final VoidCallback? onDelete;
  final bool showDelete;

  const SkillItem({
    Key? key,
    required this.skillName,
    required this.level,
    this.onDelete,
    this.showDelete = false,
  }) : super(key: key);

  Color _getLevelColor() {
    switch (level) {
      case 'Beginner':
        return Colors.blue;
      case 'Intermediate':
        return Colors.orange;
      case 'Expert':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 40,
            decoration: BoxDecoration(
              color: _getLevelColor(),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skillName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getLevelColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    level,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getLevelColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showDelete && onDelete != null)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Colors.red[300],
              ),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}