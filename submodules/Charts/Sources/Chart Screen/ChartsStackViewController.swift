//
//  ChartsStackViewController.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/13/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

class ChartsStackViewController: UIViewController {
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var psLabel: UILabel!
    @IBOutlet private var ppsLabel: UILabel!
    @IBOutlet private var animationButton: ChartVisibilityItemView!

    private var sections: [ChartStackSection] = []
    
    private var colorMode: ColorMode = .night
    private var colorModeButton: UIBarButtonItem!
    private var performFastAnimation: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Statistics"
        colorModeButton = UIBarButtonItem(title: colorMode.switchTitle, style: .plain, target: self, action: #selector(didTapSwitchColorMode))
        navigationItem.rightBarButtonItem = colorModeButton
        
        apply(colorMode: colorMode, animated: false)
        
        self.navigationController?.navigationBar.barStyle = .black
        self.navigationController?.navigationBar.isTranslucent = false
        
        self.view.isUserInteractionEnabled = false
        animationButton.backgroundColor = .clear
        animationButton.tapClosure = { [weak self] in
            guard let self = self else { return }
            self.setSlowAnimationEnabled(!self.animationButton.isChecked)
        }
        self.setSlowAnimationEnabled(false)

        loadChart1()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DispatchQueue.main.async {
            self.view.setNeedsUpdateConstraints()
            self.view.setNeedsLayout()
        }
    }
    
    func loadChart1() {
        ChartsDataLoader.overviewData(type: .generalLines, sync: true, success: { collection in
            let generalLinesChartController = GeneralLinesChartController(chartsCollection: collection)
            self.addSection(controller: generalLinesChartController, title: "FOLLOWERS")
            generalLinesChartController.getDetailsData = { date, completion in
                ChartsDataLoader.detaildData(type: .generalLines, date: date, success: { collection in
                    completion(collection)
                }, failure: { error in
                    completion(nil)
                })
            }
            DispatchQueue.main.async {
                self.loadChart2()
            }
        })
    }
    
    func loadChart2() {
        ChartsDataLoader.overviewData(type: .twoAxisLines, success: { collection in
            let twoAxisLinesChartController = TwoAxisLinesChartController(chartsCollection: collection)
            self.addSection(controller: twoAxisLinesChartController, title: "INTERACTIONS")
            twoAxisLinesChartController.getDetailsData = { date, completion in
                ChartsDataLoader.detaildData(type: .twoAxisLines, date: date, success: { collection in
                    completion(collection)
                }, failure: { error in
                    completion(nil)
                })
            }
            DispatchQueue.main.async {
                self.loadChart3()
            }
        })
    }
    
    func loadChart3() {
        ChartsDataLoader.overviewData(type: .stackedBars, success: { collection in
            let stackedBarsChartController = StackedBarsChartController(chartsCollection: collection)
            self.addSection(controller: stackedBarsChartController, title: "FRUITS")
            stackedBarsChartController.getDetailsData = { date, completion in
                ChartsDataLoader.detaildData(type: .stackedBars, date: date, success: { collection in
                    completion(collection)
                }, failure: { error in
                    completion(nil)
                })
            }
            DispatchQueue.main.async {
                self.loadChart4()
            }
        })
    }
    
    func loadChart4() {
        ChartsDataLoader.overviewData(type: .dailyBars, success: { collection in
            let dailyBarsChartController = DailyBarsChartController(chartsCollection: collection)
            self.addSection(controller: dailyBarsChartController, title: "VIEWS")
            dailyBarsChartController.getDetailsData = { date, completion in
                ChartsDataLoader.detaildData(type: .dailyBars, date: date, success: { collection in
                    completion(collection)
                }, failure: { error in
                    completion(nil)
                })
            }
            DispatchQueue.main.async {
                self.loadChart5()
            }
        })
    }
    
    func loadChart5() {
        ChartsDataLoader.overviewData(type: .percentPie, success: { collection in
            let percentPieChartController = PercentPieChartController(chartsCollection: collection)
            self.addSection(controller: percentPieChartController, title: "MORE FRUITS")
            self.finalizeChartsLoading()
        })
    }
    
    func setSlowAnimationEnabled(_ isEnabled: Bool) {
        animationButton.setChecked(isChecked: isEnabled, animated: true)
        if isEnabled {
            TimeInterval.animationDurationMultipler = 5
        } else {
            TimeInterval.animationDurationMultipler = 1
        }
    }
    
    func finalizeChartsLoading() {
        self.view.isUserInteractionEnabled = true
    }
    
    func addSection(controller: BaseChartController, title: String) {
        let section = Bundle.main.loadNibNamed("ChartStackSection", owner: nil, options: nil)?.first as! ChartStackSection
        section.frame = UIScreen.main.bounds
        section.layoutIfNeeded()
        section.setup(controller: controller, title: title)
        section.apply(colorMode: colorMode, animated: false)
        stackView.addArrangedSubview(section)
        sections.append(section)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return (colorMode == .day) ? .default : .lightContent
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
    
    @objc private func didTapSwitchColorMode() {
        self.colorMode = self.colorMode == .day ? .night : .day
        apply(colorMode: self.colorMode, animated: !performFastAnimation)
        colorModeButton.title = colorMode.switchTitle
    }
}

extension ChartsStackViewController: UIScrollViewDelegate {
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        performFastAnimation = decelerate
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        performFastAnimation = false
    }
}

extension ChartsStackViewController: ColorModeContainer {
    func apply(colorMode: ColorMode, animated: Bool) {

        UIView.perform(animated: animated) {
            self.psLabel.setTextColor(colorMode.sectionTitleColor, animated: animated && self.psLabel.isVisibleInWindow)
            self.ppsLabel.setTextColor(colorMode.sectionTitleColor, animated: animated && self.ppsLabel.isVisibleInWindow)
            self.animationButton.item = ChartVisibilityItem(title: "Enable slow animations",
                                                            color: colorMode.sectionTitleColor)
            
            self.view.backgroundColor = colorMode.tableBackgroundColor
            
            if (animated) {
                let animation = CATransition()
                animation.timingFunction = CAMediaTimingFunction.init(name: .linear)
                animation.type = .fade
                animation.duration = .defaultDuration
                self.navigationController?.navigationBar.layer.add(animation, forKey: "kCATransitionColorFade")
            }
            
            self.navigationController?.navigationBar.tintColor = colorMode.actionButtonColor
            self.navigationController?.navigationBar.barTintColor = colorMode.chartBackgroundColor
            self.navigationController?.navigationBar.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 17, weight: .medium),
                                                                            .foregroundColor: colorMode.viewTintColor]
            self.view.layoutIfNeeded()
        }
        self.setNeedsStatusBarAppearanceUpdate()
        
        for section in sections {
            section.apply(colorMode: colorMode, animated: animated && section.isVisibleInWindow)
        }
    }
}

extension ColorMode {
    var switchTitle: String {
        switch self {
        case .day:
            return "Night Mode"
        case .night:
            return "Day Mode"
        }
    }
}
