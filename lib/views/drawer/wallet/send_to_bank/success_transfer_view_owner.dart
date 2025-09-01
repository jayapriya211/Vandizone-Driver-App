import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../../utils/assets.dart';
import '../../../../utils/constant.dart';

class SuccessTransferView extends StatelessWidget {

  const SuccessTransferView({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        AssetImages.successtransfer,
                        width: 150,
                        height: 150,
                      ),
                      const Gap(25),
                      Text(
                        'Withdrawal Request Submitted!',
                        style: blackSemiBold20,
                      ),
                      const Gap(15),
                      // Withdrawal details card
                      const Text(
                        'Note: Withdrawals typically take 3-5 business days to process',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Back To Home', style: primarySemiBold18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: blackMedium16),
      ],
    );
  }
}