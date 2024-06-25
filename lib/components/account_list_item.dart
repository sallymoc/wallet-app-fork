import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:mobx/mobx.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

import 'package:qubic_wallet/components/amount_formatted.dart';
import 'package:qubic_wallet/components/copyable_text.dart';
import 'package:qubic_wallet/components/currency_amount.dart';
import 'package:qubic_wallet/components/qubic_amount.dart';
import 'package:qubic_wallet/components/qubic_asset.dart';
import 'package:qubic_wallet/di.dart';
import 'package:qubic_wallet/flutter_flow/theme_paddings.dart';
import 'package:qubic_wallet/helpers/id_validators.dart';
import 'package:qubic_wallet/helpers/re_auth_dialog.dart';
import 'package:qubic_wallet/models/qubic_list_vm.dart';
import 'package:qubic_wallet/pages/main/wallet_contents/assets.dart';
import 'package:qubic_wallet/pages/main/wallet_contents/explorer/explorer_result_page.dart';
import 'package:qubic_wallet/pages/main/wallet_contents/receive.dart';
import 'package:qubic_wallet/pages/main/wallet_contents/reveal_seed/reveal_seed.dart';
import 'package:qubic_wallet/pages/main/wallet_contents/reveal_seed/reveal_seed_warning_sheet.dart';
import 'package:qubic_wallet/pages/main/wallet_contents/send.dart';
import 'package:qubic_wallet/pages/main/wallet_contents/transfers/transactions_for_id.dart';
import 'package:qubic_wallet/smart_contracts/sc_info.dart';
import 'package:qubic_wallet/stores/application_store.dart';
import 'package:qubic_wallet/stores/settings_store.dart';
import 'package:qubic_wallet/styles/inputDecorations.dart';
import 'package:qubic_wallet/styles/textStyles.dart';
import 'package:qubic_wallet/styles/themed_controls.dart';

enum CardItem { delete, rename, reveal, viewTransactions, viewInExplorer }

class AccountListItem extends StatefulWidget {
  final QubicListVm item;

  AccountListItem({super.key, required this.item});

  @override
  State<AccountListItem> createState() => _AccountListItemState();
}

class _AccountListItemState extends State<AccountListItem> {
  final _formKey = GlobalKey<FormBuilderState>();

  final SettingsStore settingsStore = getIt<SettingsStore>();
  final ApplicationStore appStore = getIt<ApplicationStore>();

  bool totalBalanceVisible = true;
  late ReactionDisposer disposer;

  @override
  void initState() {
    super.initState();
    totalBalanceVisible = settingsStore.settings.totalBalanceVisible ?? true;

    disposer = autorun((_) {
      setState(() {
        totalBalanceVisible = settingsStore.totalBalanceVisible;
      });
    });
  }

  @override
  void dispose() {
    disposer();
    super.dispose();
  }

  showRenameDialog(BuildContext context) {
    late BuildContext dialogContext;
    final controller = TextEditingController();

    controller.text = widget.item.name;
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.item.name.length,
    );

    // set up the buttons
    Widget cancelButton = ThemedControls.transparentButtonNormal(
        onPressed: () {
          Navigator.pop(dialogContext);
        },
        text: "Cancel");

    Widget continueButton = ThemedControls.primaryButtonNormal(
      text: "Rename",
      onPressed: () {
        if (_formKey.currentState?.instantValue["accountName"] ==
            widget.item.name) {
          Navigator.pop(dialogContext);
          return;
        }

        _formKey.currentState?.validate();
        if (!_formKey.currentState!.isValid) {
          return;
        }

        appStore.setName(widget.item.publicId,
            _formKey.currentState?.instantValue["accountName"]);

        //appStore.removeID(item.publicId);
        Navigator.pop(dialogContext);
      },
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("Rename Account", style: TextStyles.alertHeader),
      scrollable: true,
      content: FormBuilder(
          key: _formKey,
          child: SizedBox(
              height: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  FormBuilderTextField(
                    name: 'accountName',
                    //initialValue: item.name,
                    decoration: ThemeInputDecorations.normalInputbox.copyWith(
                      hintText: "New name",
                    ),
                    controller: controller,
                    focusNode: FocusNode()..requestFocus(),
                    style: TextStyles.inputBoxNormalStyle,
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      CustomFormFieldValidators.isNameAvailable(
                          currentQubicIDs: appStore.currentQubicIDs,
                          ignorePublicId: widget.item.name)
                    ]),
                  ),
                ],
              ))),
      actions: [
        cancelButton,
        continueButton,
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        dialogContext = context;
        return alert;
      },
    );
  }

  showRemoveDialog(BuildContext context) {
    late BuildContext dialogContext;

    // set up the buttons
    Widget cancelButton = ThemedControls.transparentButtonNormal(
        onPressed: () {
          Navigator.pop(dialogContext);
        },
        text: "Cancel");

    Widget continueButton = ThemedControls.primaryButtonNormal(
      text: "Yes",
      onPressed: () async {
        await appStore.removeID(widget.item.publicId);
        Navigator.pop(dialogContext);
      },
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("Delete Qubic Account", style: TextStyles.alertHeader),
      content: Text(
          "Are you sure you want to delete this Qubic Account from your wallet? (Any funds associated with this account will not be removed)\n\nMAKE SURE YOU HAVE A BACKUP OF YOUR PRIVATE SEED BEFORE REMOVING THIS ACCOUNT!",
          style: TextStyles.alertText),
      actions: [
        cancelButton,
        continueButton,
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        dialogContext = context;
        return alert;
      },
    );
  }

  Widget getCardMenu(BuildContext context) {
    return Theme(
        data: Theme.of(context).copyWith(
            menuTheme: MenuThemeData(
                style: MenuStyle(
          surfaceTintColor:
              MaterialStateProperty.all(LightThemeColors.cardBackground),
          elevation: MaterialStateProperty.all(50),
          backgroundColor:
              MaterialStateProperty.all(LightThemeColors.cardBackground),
        ))),
        child: PopupMenuButton<CardItem>(
            tooltip: "",
            icon: Icon(Icons.more_horiz,
                color: LightThemeColors.primary.withAlpha(140)),
            // Callback that sets the selected popup menu item.
            onSelected: (CardItem menuItem) async {
              // setState(() {
              //   selectedMenu = item;
              // });
              if (menuItem == CardItem.rename) {
                showRenameDialog(context);
              }

              if (menuItem == CardItem.delete) {
                showRemoveDialog(context);
              }

              if (menuItem == CardItem.viewInExplorer) {
                pushScreen(
                  context,
                  screen: ExplorerResultPage(
                    resultType: ExplorerResultType.publicId,
                    qubicId: widget.item.publicId,
                  ),
                  withNavBar: false,
                  pageTransitionAnimation: PageTransitionAnimation.cupertino,
                );
              }

              if (menuItem == CardItem.viewTransactions) {
                pushScreen(
                  context,
                  screen: TransactionsForId(
                      publicQubicId: widget.item.publicId, item: widget.item),
                  withNavBar: false, // OPTIONAL VALUE. True by default.
                  pageTransitionAnimation: PageTransitionAnimation.cupertino,
                );
              }

              if (menuItem == CardItem.reveal) {
                showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useRootNavigator: true,
                    backgroundColor: LightThemeColors.background,
                    builder: (BuildContext context) {
                      return RevealSeedWarningSheet(
                          item: widget.item,
                          onAccept: () async {
                            if (await reAuthDialog(context) == false) {
                              Navigator.pop(context);
                              return;
                            }
                            Navigator.pop(context);
                            pushScreen(
                              context,
                              screen: RevealSeed(item: widget.item),
                              withNavBar:
                                  false, // OPTIONAL VALUE. True by default.
                              pageTransitionAnimation:
                                  PageTransitionAnimation.cupertino,
                            );
                          },
                          onReject: () async {
                            Navigator.pop(context);
                          });
                    });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<CardItem>>[
                  const PopupMenuItem<CardItem>(
                    value: CardItem.viewTransactions,
                    child: Text('View transfers'),
                  ),
                  PopupMenuItem<CardItem>(
                    value: CardItem.viewInExplorer,
                    child: Text('View in explorer'),
                    enabled:
                        widget.item.amount != null && widget.item.amount! > 0,
                  ),
                  const PopupMenuItem<CardItem>(
                    value: CardItem.reveal,
                    child: Text('Reveal private seed'),
                  ),
                  const PopupMenuItem<CardItem>(
                    value: CardItem.rename,
                    child: Text('Rename'),
                  ),
                  const PopupMenuItem<CardItem>(
                    value: CardItem.delete,
                    child: Text('Delete'),
                  ),
                ]));
  }

  Widget getButtonBar(BuildContext context) {
    return ButtonBar(
      alignment: MainAxisAlignment.start,
      overflowDirection: VerticalDirection.down,
      overflowButtonSpacing: ThemePaddings.smallPadding,
      buttonPadding: const EdgeInsets.fromLTRB(ThemeFontSizes.large,
          ThemeFontSizes.large, ThemeFontSizes.large, ThemeFontSizes.large),
      children: [
        widget.item.amount != null
            ? ThemedControls.primaryButtonBig(
                onPressed: () {
                  // Perform some action
                  pushScreen(
                    context,
                    screen: Send(item: widget.item),
                    withNavBar: false, // OPTIONAL VALUE. True by default.
                    pageTransitionAnimation: PageTransitionAnimation.cupertino,
                  );
                },
                text: "Send",
                icon: LightThemeColors.shouldInvertIcon
                    ? ThemedControls.invertedColors(
                        child: Image.asset("assets/images/send.png"))
                    : Image.asset("assets/images/send.png"))
            : Container(),
        ThemedControls.primaryButtonBig(
          onPressed: () {
            pushScreen(
              context,
              screen: Receive(item: widget.item),
              withNavBar: false, // OPTIONAL VALUE. True by default.
              pageTransitionAnimation: PageTransitionAnimation.cupertino,
            );
          },
          icon: !LightThemeColors.shouldInvertIcon
              ? ThemedControls.invertedColors(
                  child: Image.asset("assets/images/receive.png"))
              : Image.asset("assets/images/receive.png"),
          text: "Receive",
        ),
        widget.item.assets.keys.isNotEmpty
            ? ThemedControls.primaryButtonBig(
                text: "Assets",
                onPressed: () {
                  pushScreen(
                    context,
                    screen: Assets(PublicId: widget.item.publicId),
                    withNavBar: false, // OPTIONAL VALUE. True by default.
                    pageTransitionAnimation: PageTransitionAnimation.cupertino,
                  );
                })
            : Container()
      ],
    );
  }

  Widget getAssets(BuildContext context) {
    List<Widget> shares = [];

    for (var key in widget.item.assets.keys) {
      var asset = widget.item.assets[key];
      bool isToken = asset!.contractIndex == QubicSCID.qX.contractIndex &&
          asset!.contractName != "QX";
      String text = isToken ? " Token" : " Share";
      int num = asset.ownedAmount ?? asset.possessedAmount ?? 0;
      if (num != 1) {
        text += "s";
      }
      shares.add(AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (Widget child, Animation<double> animation) {
            //return FadeTransition(opacity: animation, child: child);
            return SizeTransition(sizeFactor: animation, child: child);
            //return ScaleTransition(scale: animation, child: child);
          },
          child: widget.item.assets[key] != null
              ? AmountFormatted(
                  key: ValueKey<String>(
                      "qubicAsset${widget.item.publicId}-${key}-${widget.item.assets[key]}"),
                  amount: widget.item.assets[key]!.ownedAmount,
                  isInHeader: false,
                  labelOffset: -0,
                  labelHorizOffset: -6,
                  textStyle: MediaQuery.of(context).size.width < 400
                      ? TextStyles.accountAmount.copyWith(fontSize: 16)
                      : TextStyles.accountAmount,
                  labelStyle: TextStyles.accountAmountLabel,
                  currencyName: widget.item.assets[key]!.assetName + text,
                )
              : Container()));
    }
    return AnimatedCrossFade(
        firstChild: Container(
            width: double.infinity,
            alignment: Alignment.centerRight,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.end, children: shares)),
        secondChild: Text("*******"),
        crossFadeState: totalBalanceVisible
            ? CrossFadeState.showFirst
            : CrossFadeState.showSecond,
        duration: 300.ms);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        constraints: const BoxConstraints(minWidth: 400, maxWidth: 500),
        child: Card(
            color: LightThemeColors.cardBackground,
            elevation: 0,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ThemePaddings.normalPadding,
                      ThemePaddings.normalPadding,
                      ThemePaddings.normalPadding,
                      0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Flex(
                            direction: Axis.horizontal,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                  fit: FlexFit.loose,
                                  child: Text(widget.item.name,
                                      style: TextStyles.accountName)),
                              getCardMenu(context)
                            ]),
                        ThemedControls.spacerVerticalSmall(),
                        Text(widget.item.publicId),
                        ThemedControls.spacerVerticalSmall(),
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 300),
                          firstChild: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                //return FadeTransition(opacity: animation, child: child);
                                return SizeTransition(
                                    sizeFactor: animation, child: child);
                                //return ScaleTransition(scale: animation, child: child);
                              },
                              child: AmountFormatted(
                                key: ValueKey<String>(
                                    "qubicAmount${widget.item.publicId}-${widget.item.amount}"),
                                amount: widget.item.amount,
                                isInHeader: false,
                                labelOffset: -0,
                                labelHorizOffset: -6,
                                textStyle:
                                    MediaQuery.of(context).size.width < 400
                                        ? TextStyles.accountAmount
                                            .copyWith(fontSize: 22)
                                        : TextStyles.accountAmount,
                                labelStyle: TextStyles.accountAmountLabel,
                                currencyName: 'QUBIC',
                              )),
                          secondChild: Text("******",
                              style: MediaQuery.of(context).size.width < 400
                                  ? TextStyles.accountAmount
                                      .copyWith(fontSize: 22)
                                  : TextStyles.accountAmount),
                          crossFadeState: totalBalanceVisible
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                        ),
                        getAssets(context)
                      ])),
              getButtonBar(context),
            ])));
  }
}
