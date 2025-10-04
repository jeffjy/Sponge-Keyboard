//
//  KeyboardViewController.swift
//  sponge
//
//  Created by Jeff on 9/29/25.
//  Copyright © 2025 Jeff. All rights reserved.
//

import Foundation

import UIKit
import AudioToolbox

class KeyboardViewController: UIInputViewController {

    @IBOutlet var nextKeyboardButton: UIButton!
    
    // Lazy UI build helpers
    private var didSetupUI = false
    private var lastLayoutWidth: CGFloat = 0
    private var borderView: UIView?
    private var cachedSelectedExtensions: [Extension] = []
    private var didSetupSpecialRow = false
    
    let lightImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    var settings: Specialization = EnglishQ()
    
    var selectedRows = [[""]]
    var keyProbabilities = [[1.0]]
    
    let poundKeyStates = ["off", "numeric"]
    var poundKeyCurrentState = 0
    
    let topPadding: CGFloat = 46
    let keyHeight: CGFloat = 48
    var keyWidth: CGFloat = 33
    let keySpacing: CGFloat = 4
    let rowSpacing: CGFloat = 9
    let shiftWidth: CGFloat = 45
    let shiftHeight: CGFloat = 48
    
    var spaceWidth: CGFloat = 170
    
    let spaceHeight: CGFloat = 45
    let nextWidth: CGFloat = 50
    let returnWidth: CGFloat = 90
    let keyboardHeight: CGFloat = 260

    // Delete key sizing and spacing
    let deleteGapFromLetters: CGFloat = 8   // space between last letter (e.g., "m") and delete
    let deleteMinWidth: CGFloat = 44        // ensure tappable size
    let deleteMaxWidth: CGFloat = 110       // keep it a bit smaller than before
    
    var buttons: Array<UIButton> = []
    var shiftKey: KeyButton?
    var deleteKey: KeyButton?
    var spaceKey: UIButton?
    var poundKey: KeyButton?
    //var nextKeyboardButton: KeyButton?
    var returnButton: KeyButton?
    
    var shiftPosArr = [0]
    var numCharacters = 0
    var spacePressed = false
    var spaceTimer: Timer?
    var currentWord = ""

    // Run-length constraint state for randomizeCase
    private var rcLastIsUpper: Bool? = nil
    private var rcRunLen: Int = 0

    var randomCapsEnabled = true
    private func randomizeCase(_ s: String) -> String {
        var out = ""
        for ch in s {
            if let scalar = ch.unicodeScalars.first, CharacterSet.letters.contains(scalar) {
                if rcLastIsUpper == nil {
                    let pick = Bool.random()
                    rcLastIsUpper = pick
                    rcRunLen = 1
                    out.append(pick ? Character(String(ch).uppercased()) : Character(String(ch).lowercased()))
                } else {
                    let mustFlip = rcRunLen >= 2
                    let flip = mustFlip ? true : Bool.random()
                    let nextIsUpper = flip ? !(rcLastIsUpper!) : rcLastIsUpper!
                    if nextIsUpper == rcLastIsUpper! {
                        rcRunLen += 1
                    } else {
                        rcLastIsUpper = nextIsUpper
                        rcRunLen = 1
                    }
                    out.append(nextIsUpper ? Character(String(ch).uppercased()) : Character(String(ch).lowercased()))
                }
            } else {
                out.append(ch)
                if ch == " " || ch == "\n" || ch == "\t" { rcLastIsUpper = nil; rcRunLen = 0 }
            }
        }
        return out
    }
    
    var textTracker: TextTracker?
    var specialRowController: SpecialRowController?
    
    private weak var heightConstraint: NSLayoutConstraint?
    override func viewWillAppear(_ animated: Bool){
        super.viewWillAppear(animated)
        guard nil == self.heightConstraint else { return }
        
        // We must add a subview with an `instrinsicContentSize` that uses autolayout to force the height constraint to be recognized.
        //
        let emptyView = UILabel(frame: .zero)
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyView);
        
        let heightConstraint = NSLayoutConstraint(item: view,
                                                  attribute: .height,
                                                  relatedBy: .equal,
                                                  toItem: nil,
                                                  attribute: .notAnAttribute,
                                                  multiplier: 0.0,
                                                  constant: self.keyboardHeight)
        heightConstraint.priority = .required - 1
        view.addConstraint(heightConstraint)
        self.heightConstraint = heightConstraint
        self.lightImpactFeedbackGenerator.prepare()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Load settings
        if let userDefaults = UserDefaults(suiteName: "group.heren.kifboard") {
            if let flavor = userDefaults.string(forKey: "flavor"){
                if(flavor == "English"){
                    self.settings = EnglishQ()
                }else if(flavor == "EnglishQDark"){
                    self.settings = EnglishQDark()
                }
            }
        }
        
        // Perform custom UI setup here
        self.view.backgroundColor = self.settings.keyboardBgColor;
        self.view.isOpaque = true
        
        let namespace = Bundle.main.infoDictionary?["CFBundleExecutable"] as? String ?? ""
        var selectedExtensions: [Extension] = []
        if let userDefaults = UserDefaults(suiteName: "group.heren.kifboard") {
            let arr = userDefaults.stringArray(forKey: "extensions") ?? []
            for e in arr {
                if let cls = NSClassFromString("\(namespace).\(e)") as? Extension.Type {
                    selectedExtensions.append(cls.init())
                }
            }
        }
        self.cachedSelectedExtensions = selectedExtensions
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        buildKeyboardIfNeeded()
        relayoutIfNeededForWidthChange()
    }
    
    private func buildKeyboardIfNeeded() {
        // Ensure we only build once and only when we have a valid width
        let width = self.view.bounds.width
        guard width > 0 else { return }
        if didSetupUI { return }
        didSetupUI = true
        lastLayoutWidth = width

        // Top border (added once)
        let border = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 0.5))
        border.autoresizingMask = [.flexibleWidth]
        border.backgroundColor = UIColor(red: 210.0/255, green: 205.0/255, blue: 193.0/255, alpha: 1)
        self.view.addSubview(border)
        self.borderView = border

        // Build rows and keys now that width is known
        self.setupThirdRow()
        self.setupBottomRow()

        self.selectedRows = self.settings.layout
        self.keyProbabilities = self.settings.layout_prob
        self.setupKeys()
        self.redrawButtonsForShift()

        // Now that keys exist, initialize the text tracker immediately
        self.textTracker = TextTracker(
            shiftKey: self.shiftKey,
            textDocumentProxy: self.textDocumentProxy,
            selectedExtensions: self.cachedSelectedExtensions)

        // Defer heavy dictionary loading and special row creation slightly to avoid blocking the first frame
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard self.didSetupSpecialRow == false else { return }
            let spell = SpellCheckController(specialization: self.settings)
            self.specialRowController = SpecialRowController(
                textTracker: self.textTracker!,
                parentView: self.view,
                spellCheckController: spell,
                specialization: self.settings,
                selectedExtensions: self.cachedSelectedExtensions)

            self.specialRowController?.drawSpecialRow(array: [
                [SpecialRowKeyPlaceHolder(text: ""), SpecialRowKeyPlaceHolder(text: ""), SpecialRowKeyPlaceHolder(text: "")]
            ])
            self.didSetupSpecialRow = true
        }
    }
    
    private func relayoutIfNeededForWidthChange() {
        guard didSetupUI else { return }
        let width = self.view.bounds.width
        guard width > 0, width != lastLayoutWidth else { return }
        lastLayoutWidth = width

        // Update frames for third row keys
        let thirdRowTopPadding: CGFloat = topPadding + (keyHeight + rowSpacing) * 2
        // shiftKey frame will be set after computing deleteWidth to keep symmetry
        // self.shiftKey?.frame = CGRect(x: 2.0, y: thirdRowTopPadding, width: shiftWidth, height: shiftHeight)
        // Compute delete key size with a fixed gap from the last letter key
        let thirdRowCount = (self.selectedRows.indices.contains(2) ? self.selectedRows[2].count : 7)
        let computedKeyWidth = (width / 10.0) - keySpacing
        let thirdRowLeftMargin = ceil((width - (CGFloat(thirdRowCount) - 1) * (keySpacing + computedKeyWidth) - computedKeyWidth) / 2.0)
        // Ensure there is a bit of breathing room between "m" and delete
        let maxAllowedDeleteWidth = max(0, thirdRowLeftMargin - deleteGapFromLetters - 2)
        let deleteWidth = max(deleteMinWidth, min(deleteMaxWidth, maxAllowedDeleteWidth))
        self.deleteKey?.frame = CGRect(x: width - deleteWidth - 2.0, y: thirdRowTopPadding, width: deleteWidth, height: shiftHeight)
        // Keep shift width symmetric to delete for visual balance (even though shift isn't visible)
        self.shiftKey?.frame = CGRect(x: 2.0, y: thirdRowTopPadding, width: deleteWidth, height: shiftHeight)

        // Update frames for bottom row keys
        let bottomRowTopPadding = topPadding + keyHeight * 3 + rowSpacing * 2 + 8
        
        let sideWidth = min(120, max(60, floor(width * 0.18)))
        let globeX: CGFloat = 2
        let globeWidth: CGFloat = sideWidth
        let poundX: CGFloat = globeX + globeWidth + 2
        let poundWidth: CGFloat = sideWidth
        
        // Use a larger Return button and let the space bar fill the remaining area with small side gaps
        let returnDynamicWidth: CGFloat = max(returnWidth, 120)
        let leftBound = poundX + poundWidth + 2
        let rightBound = width - returnDynamicWidth - 2
        let available = max(0, rightBound - leftBound)
        let spaceSideGap: CGFloat = 6
        self.spaceWidth = max(0, available - 2 * spaceSideGap)
        let spaceX = leftBound + spaceSideGap
        
        self.spaceKey?.frame = CGRect(x: spaceX, y: bottomRowTopPadding, width: spaceWidth, height: spaceHeight)
        self.nextKeyboardButton?.frame = CGRect(x: globeX, y: bottomRowTopPadding, width: globeWidth, height: spaceHeight)
        self.poundKey?.frame = CGRect(x: poundX, y: bottomRowTopPadding, width: poundWidth, height: spaceHeight)
        self.returnButton?.frame = CGRect(x: width - returnDynamicWidth - 2, y: bottomRowTopPadding, width: returnDynamicWidth, height: spaceHeight)

        // Rebuild primary letter keys to match the new width
        self.setupKeys()
        self.redrawButtonsForShift()
    }
    
    func setupThirdRow(){
        let thirdRowTopPadding: CGFloat = topPadding + (keyHeight + rowSpacing) * 2
        self.shiftKey = KeyButton(
            frame: CGRect(x: 2.0, y: thirdRowTopPadding, width:shiftWidth, height:shiftHeight),
            settings: self.settings)
        
        self.shiftKey!.setMargin(marginX: 10, marginY: 4, offsetX: 0, offsetY: 0)
        
        self.shiftKey!.addTarget(self, action:#selector(shiftKeyPressed(sender:)), for: .touchUpInside)
        self.shiftKey!.isSelected = true
        self.shiftKey!.setTitle("sponge", for: .normal)
        self.shiftKey!.setTitle("sponge", for: .selected)
        self.shiftKey?.backgroundColor = UIColor.systemPurple
        // Shift key kept for internal caps state only; not added to view.
        
        self.shiftKey!.titleLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 22)
        self.shiftKey!.titleLabel?.adjustsFontSizeToFitWidth = true
        self.shiftKey!.titleLabel?.minimumScaleFactor = 0.5
        self.shiftKey!.titleLabel?.lineBreakMode = .byClipping
        self.shiftKey!.titleLabel?.numberOfLines = 1
        self.shiftKey!.titleLabel?.baselineAdjustment = .alignCenters
        
        let viewWidth = self.view.bounds.width
        let approxThirdRowCount: CGFloat = 7
        let computedKeyWidth = (viewWidth / 10.0) - keySpacing
        let thirdRowLeftMargin = ceil((viewWidth - (approxThirdRowCount - 1) * (keySpacing + computedKeyWidth) - computedKeyWidth) / 2.0)
        // Respect a small gap to the last letter key and keep delete modestly sized
        let maxAllowedDeleteWidth = max(0, thirdRowLeftMargin - deleteGapFromLetters - 2)
        let initialDeleteWidth = max(deleteMinWidth, min(deleteMaxWidth, maxAllowedDeleteWidth))

        self.shiftKey?.frame = CGRect(x: 2.0, y: thirdRowTopPadding, width: initialDeleteWidth, height: shiftHeight)
        self.shiftKey!.titleLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 22)
        self.shiftKey!.titleLabel?.adjustsFontSizeToFitWidth = true
        self.shiftKey!.titleLabel?.minimumScaleFactor = 0.5
        self.shiftKey!.titleLabel?.lineBreakMode = .byClipping
        self.shiftKey!.titleLabel?.numberOfLines = 1
        self.shiftKey!.titleLabel?.baselineAdjustment = .alignCenters

        deleteKey = KeyButton(
            frame: CGRect(x:viewWidth - initialDeleteWidth - 2.0, y: thirdRowTopPadding, width: initialDeleteWidth, height: shiftHeight),
            settings: self.settings)
        
        deleteKey!.setMargin(marginX: 10, marginY: 4, offsetX: 0, offsetY: 0)
        deleteKey!.addTarget(self, action:#selector(deleteKeyPressed(sender:)), for: .touchUpInside)
        let longGesture = UILongPressGestureRecognizer(target: self, action: #selector(deleteKeyLongPressed(sender: )))
        deleteKey!.addGestureRecognizer(longGesture)
        self.deleteKey!.addTarget(self, action:#selector(deleteKeySlideOut(sender:)), for: .touchDragExit)
        
        
        deleteKey!.setTitle("delete", for: .normal)
        deleteKey!.titleLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 18)
        deleteKey!.titleLabel?.adjustsFontSizeToFitWidth = true
        deleteKey!.titleLabel?.minimumScaleFactor = 0.3
        deleteKey!.titleLabel?.allowsDefaultTighteningForTruncation = true
        deleteKey!.titleLabel?.lineBreakMode = .byClipping
        deleteKey!.titleLabel?.numberOfLines = 1
        deleteKey!.titleLabel?.baselineAdjustment = .alignCenters
        //deleteKey!.setTitle("*", for: .highlighted)
        self.view.addSubview(deleteKey!)
    }
    
    func setupBottomRow(){
        
        let viewWidth = self.view.bounds.width
        let bottomRowTopPadding = topPadding + keyHeight * 3 + rowSpacing * 2 + 8
        
        // Dynamic width for left-side buttons to reduce excess gray space
        let sideWidth = min(120, max(60, floor(viewWidth * 0.18)))
        let globeX: CGFloat = 2
        let globeWidth: CGFloat = sideWidth
        let poundX: CGFloat = globeX + globeWidth + 2
        let poundWidth: CGFloat = sideWidth
        
        // Compute bounds of the available area between the pound key and the return key
        let returnDynamicWidth: CGFloat = max(returnWidth, 120)
        let leftBound = poundX + poundWidth + 2 // right edge of pound key + spacing
        let rightBound = viewWidth - returnDynamicWidth - 2    // left edge of return key - spacing
        let available = max(0, rightBound - leftBound)
        let spaceSideGap: CGFloat = 6
        self.spaceWidth = max(0, available - 2 * spaceSideGap)
        let spaceX = leftBound + spaceSideGap
        
        spaceKey = KeyButton(
            frame: CGRect(x: spaceX, y: bottomRowTopPadding, width: spaceWidth, height: spaceHeight),
            settings: self.settings)
        
        spaceKey!.setTitle(" ", for: .normal)
        spaceKey!.addTarget(self, action:#selector(keyPressed(sender:)), for: .touchUpInside)
        self.view.addSubview(spaceKey!)
        
        self.nextKeyboardButton = KeyButton(
            frame:CGRect(x: globeX, y: bottomRowTopPadding, width: globeWidth, height: spaceHeight),
            settings: self.settings)
        
        nextKeyboardButton!.titleLabel?.font = UIFont(name: "HelveticaNeue-Light", size:18)
        nextKeyboardButton!.setTitle("🌐", for: .normal)
        nextKeyboardButton!.addTarget(self, action: #selector(nextKeyboardTapped(_:)), for: .touchUpInside)
        view.addSubview(self.nextKeyboardButton!)
        
        // Removed leftAnchor constraint line as requested
        
        poundKey = KeyButton(
            frame: CGRect(x: poundX, y: bottomRowTopPadding, width: poundWidth, height: spaceHeight),
            settings: self.settings)
        
        poundKey!.setTitle(".?123", for: .normal)
        poundKey!.titleLabel?.adjustsFontSizeToFitWidth = true
        poundKey!.titleLabel?.minimumScaleFactor = 0.7
        poundKey!.titleLabel?.lineBreakMode = .byClipping
        poundKey!.addTarget(self, action:#selector(poundKeyPressed(sender:)), for: .touchUpInside)
        self.view.addSubview(poundKey!)
        
        returnButton = KeyButton(
            frame: CGRect(x:viewWidth - max(returnWidth, 120) - 2, y: bottomRowTopPadding, width:max(returnWidth, 120), height:spaceHeight),
            settings: self.settings)
        
        returnButton!.setTitle(NSLocalizedString("return", comment: "Title for 'Return Key' button"), for: .normal)
        returnButton!.titleLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 22)
        returnButton!.titleLabel?.adjustsFontSizeToFitWidth = true
        returnButton!.titleLabel?.minimumScaleFactor = 0.5
        returnButton!.titleLabel?.lineBreakMode = .byClipping
        returnButton!.titleLabel?.numberOfLines = 1
        returnButton!.titleLabel?.baselineAdjustment = .alignCenters
        returnButton!.addTarget(self, action:#selector(returnKeyPressed(sender:)), for: .touchUpInside)
        self.view.addSubview(returnButton!)
    }
    
    func setupKeys(){
        var y: CGFloat = topPadding
        var width = self.view.bounds.width
        keyWidth = (width / 10.0) - keySpacing
        
        for button in self.buttons{
            button.removeFromSuperview()
        }
        self.buttons.removeAll()
        
        for (i, row) in self.selectedRows.enumerated() {
            var x: CGFloat = ceil((width - (CGFloat(row.count) - 1) * (keySpacing + keyWidth) - keyWidth) / 2.0)
            for var (k, label) in row.enumerated() {
                
                let keyProb = self.keyProbabilities[i][k]
                
                let labelArr = label.components(separatedBy: "||")
                var secondTitle = "";
                if labelArr.count == 2{
                    label = labelArr[0]
                    secondTitle = labelArr[1]
                }else{
                    label = labelArr[0]
                }
                
                let button = KeyButton(
                    frame: CGRect(x: x, y: y, width: keyWidth, height: keyHeight),
                    settings: self.settings)
                
                let capsActive = (self.shiftKey?.longSelected == true)
                button.setTitle(capsActive ? label.uppercased() : label.lowercased(), for: .normal)
                
                button.addTarget(self, action:#selector(keyPressed(sender:)), for: .touchUpInside)
                
                let longGesture = UILongPressGestureRecognizer(target: self, action: #selector(keyLongPressed(sender: )))
                button.addGestureRecognizer(longGesture)
                button.addTarget(self, action:#selector(keySlideOut(sender:)), for: .touchDragExit)
                
                button.secondaryTitle = secondTitle;
                
                if #available(iOS 15.0, *) {
                    if var config = button.configuration {
                        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 1, bottom: 0, trailing: 0)
                        button.configuration = config
                    }
                } else {
                    button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 1, bottom: 0, right: 0)
                }
                
                // Hack for A and L mimicking IOS keyboard. We need to make these adaptive later.
                if(label.uppercased() == "A"){
                    button.setMargin(marginX: 15, marginY: 4, offsetX: 0, offsetY: 0)
                }
                if(label.uppercased() == "L"){
                    button.setMargin(marginX: 15, marginY: 4, offsetX: -15, offsetY: 0)
                }
                
                self.view.addSubview(button)
                buttons.append(button)
                x += keyWidth + keySpacing
            }
            
            y += keyHeight + rowSpacing
        }
        self.redrawButtonsForShift()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated
    }
    
    override func textWillChange(_ textInput: UITextInput?) {
        // The app is about to change the document's contents. Perform any preparation here.
        
    }

    override func textDidChange(_ textInput: UITextInput?) {
        // The app has just changed the document's contents, the document context has been updated.
        
        // something cleared the view.
        if self.textDocumentProxy.documentContextAfterInput == nil && self.textDocumentProxy.documentContextBeforeInput == nil{
            self.textTracker?.signalSentenceEnd()
        }
        
        let proxy = self.textDocumentProxy
        let textColor: UIColor = (proxy.keyboardAppearance == .dark) ? .white : .black
        self.nextKeyboardButton?.setTitleColor(textColor, for: .normal)
    }

    @objc func returnKeyPressed(sender: UIButton) {
        
        lightImpactFeedbackGenerator.impactOccurred();
        
        self.specialRowController?.ExecuteAutoReplaces()
        
        self.textTracker?.addCharacter(ch: "\n", redrawButtons: {
            redrawButtonsForShift()
        })

        numCharacters = numCharacters + 1;
        shiftPosArr[shiftPosArr.count - 1] = shiftPosArr[shiftPosArr.count - 1] + 1;
        if shiftKey!.isSelected {
            shiftPosArr.append(0)
            self.shiftKey?.isSelected = false
            self.textTracker?.setShiftValue(shiftVal: self.shiftKey!)
        }
        
        
        spacePressed = false
    }
    
    @objc func nextKeyboardTapped(_ sender: UIButton) {
        // Immediate switch to the next input mode (faster than showing the list)
        self.advanceToNextInputMode()
    }
    
    @objc func deleteKeyPressed(sender: UIButton) {
        _ = self.textTracker?.deleteCharacter()
        self.specialRowController?.updateSpecialRow()
        spacePressed = false
    }
    
    var timer: Timer?
    @objc func deleteKeyLongPressed(sender: UILongPressGestureRecognizer) {
        
        if sender.state == .began {
            timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(handleTimer(timer:)), userInfo: nil, repeats: true)
            lightImpactFeedbackGenerator.impactOccurred();
            
        } else if sender.state == .ended || sender.state == .cancelled {
            timer?.invalidate()
            timer = nil
            }
        spacePressed = false
    }
    
    @objc func deleteKeySlideOut(sender: UIButton){
        //lightImpactFeedbackGenerator.impactOccurred();
        //AudioServicesPlaySystemSound(0x450)
        
        self.textTracker?.deleteUntilLastSpace()
        self.specialRowController?.updateSpecialRow()
        
        spacePressed = false
    }
    
    @objc private func handleTimer(timer: Timer) {
        UIDevice.current.playInputClick()
        _ = self.textTracker?.deleteCharacter()
    }
    
    @objc func shiftKeyPressed(sender: UIButton) {
        if (self.shiftKey?.longSelected == true){
            self.shiftKey!.isSelected = false
            self.shiftKey!.longSelected = false;
        }else{
            self.shiftKey!.isSelected = !self.shiftKey!.isSelected
            self.shiftKey!.longSelected = false;
        }
        
        self.textTracker?.setShiftValue(shiftVal: self.shiftKey!)
        self.shiftKey?.backgroundColor = self.settings.keyboardBgColor
        
        if shiftKey!.isSelected {
            shiftPosArr.append(0)
        }
        else if shiftPosArr[shiftPosArr.count - 1] == 0 {
            shiftPosArr.removeLast()
        }
        
        spacePressed = false
        
        redrawButtonsForShift()
    }
    
    @objc func shiftKeyLongPressed(sender: UILongPressGestureRecognizer) {
        if sender.state == .ended{
            let button = sender.view as! KeyButton
            lightImpactFeedbackGenerator.impactOccurred();
            self.shiftKeyLongPressedAction(sender: button)
        }
    }
    
    @objc func shiftKeySlideOut(sender: UIButton) {
       self.shiftKeyLongPressedAction(sender: sender)
    }
    
    private func shiftKeyLongPressedAction(sender: UIButton){
        if(self.shiftKey!.longSelected == true){
            self.shiftKey!.longSelected = false
            self.shiftKey!.isSelected = false;
            self.shiftKey?.backgroundColor = self.settings.keyboardBgColor
        }else{
            self.shiftKey!.longSelected = true
            self.shiftKey!.isSelected = true;
            self.shiftKey?.backgroundColor = UIColor.red
        }
        
        self.textTracker?.setShiftValue(shiftVal: self.shiftKey!)
        
        if shiftKey!.isSelected {
            shiftPosArr.append(0)
        }
        else if shiftPosArr[shiftPosArr.count - 1] == 0 {
            shiftPosArr.removeLast()
        }
        
        spacePressed = false
        
        redrawButtonsForShift()
    }
    
    @objc func keyPressed(sender: UIButton) {
        sender.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
        
        //sender.transform = CGAffineTransform(translationX: 0, y: -65)
        
        UIView.animate(
            withDuration: 0.14,
            delay: 0,
            options: UIView.AnimationOptions.allowUserInteraction,
            animations: {
                sender.transform = CGAffineTransform.identity
            },
            completion: { Void in()  }
        )
        
        if sender.titleLabel?.text == " "{
            self.specialRowController?.ExecuteAutoReplaces()
        }
        
        let raw = sender.titleLabel?.text ?? ""
        let capsActive = (self.shiftKey?.longSelected == true)
        let out: String
        if capsActive {
            out = raw.uppercased()
        } else {
            out = randomCapsEnabled ? randomizeCase(raw) : raw
        }
        self.textTracker?.addCharacter(ch: out, redrawButtons: {
            redrawButtonsForShift()
        })
        self.specialRowController?.updateSpecialRow()
    }
    
    @objc func keySlideOut(sender: KeyButton) {
        self.secondaryButtonAction(button: sender)
    }
    
    @objc func keyLongPressed(sender: UILongPressGestureRecognizer) {
        if sender.state == .ended{
            let button = sender.view as! KeyButton
            
            lightImpactFeedbackGenerator.impactOccurred();
            
            self.secondaryButtonAction(button: button)
        }
    }
    
    private func secondaryButtonAction(button: KeyButton){
        
        let temp = button.titleLabel?.text
        let capsActive = (self.shiftKey?.longSelected == true)
        let secondaryRaw = button.secondaryTitle ?? ""
        let secondaryShown = capsActive ? secondaryRaw.uppercased() : secondaryRaw.lowercased()
        button.setTitle(secondaryShown, for: .normal)
        
        let raw2 = button.secondaryTitle ?? ""
        let out2: String
        if capsActive {
            out2 = raw2.uppercased()
        } else {
            out2 = randomCapsEnabled ? randomizeCase(raw2) : raw2
        }
        textTracker?.addCharacter(ch: out2, redrawButtons: {
            redrawButtonsForShift()
        })
        self.specialRowController?.updateSpecialRow()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { // change 1 to desired number of seconds
            button.setTitle(temp, for: .normal)
            self.redrawButtonsForShift()
        }
    }
    
    @objc func poundKeyPressed(sender: UIButton) {
        if self.poundKeyCurrentState < poundKeyStates.count - 1{
            self.poundKeyCurrentState = self.poundKeyCurrentState + 1;
        }else{
            self.poundKeyCurrentState = 0;
        }
        let nextState = self.poundKeyStates[self.poundKeyCurrentState]
        
        lightImpactFeedbackGenerator.impactOccurred();
        self.poundKey?.setTitle(nextState == "numeric" ? "ABC" : ".?123", for: .normal)
        
        if nextState == "numeric"{
            self.selectedRows = self.settings.secondaryLayout;
            self.setupKeys()
            self.redrawButtonsForShift()
            self.specialRowController?.drawSpecialRow(array: [
                [SpecialRowKeyPlaceHolder(text: "😂", operationMode: SpecialKeyOperationMode.number),
                 SpecialRowKeyPlaceHolder(text: "😘", operationMode: SpecialKeyOperationMode.number),
                 SpecialRowKeyPlaceHolder(text: "💕", operationMode: SpecialKeyOperationMode.number),
                 SpecialRowKeyPlaceHolder(text: "❤️", operationMode: SpecialKeyOperationMode.number),
                 SpecialRowKeyPlaceHolder(text: "👍", operationMode: SpecialKeyOperationMode.number),
                 SpecialRowKeyPlaceHolder(text: "😅", operationMode: SpecialKeyOperationMode.number),
                 SpecialRowKeyPlaceHolder(text: "😥", operationMode: SpecialKeyOperationMode.number),
                 SpecialRowKeyPlaceHolder(text: "😎", operationMode: SpecialKeyOperationMode.number),
                 SpecialRowKeyPlaceHolder(text: "☺️", operationMode: SpecialKeyOperationMode.number),
                 SpecialRowKeyPlaceHolder(text: "🙃", operationMode: SpecialKeyOperationMode.number)]
                ])
        }else{
            self.selectedRows = self.settings.layout;
            self.setupKeys()
            self.redrawButtonsForShift()
        }
        if nextState == "off"{
            self.specialRowController?.clearSpecialKeys()
        }
    }
    
    func redrawButtonsForShift() {
        for button in buttons {
            var text = button.titleLabel?.text
            let capsActive = (self.shiftKey?.longSelected == true)
            if capsActive {
                text = text?.uppercased()
            } else {
                text = text?.lowercased()
            }
            button.setTitle(text, for: .normal)
            button.titleLabel?.sizeToFit()
        }
    }
}

extension KeyboardViewController: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}
