import Foundation
import SwiftSignalKit
import TelegramCore

@available(macOS 10.15, *)
func walletFiatRatesResult(
    currencyRates: [CurrencyRate]?,
    tonUsdRate: Double?
) -> Result<[WalletContext.FiatCurrency: WalletContext.FiatRate], WalletContext.SynchronizationError> {
    guard let currencyRates else { return .failure(.network) }
    guard let tonUsdRate, tonUsdRate.isFinite, tonUsdRate > 0 else { return .failure(.invalidData) }

    var byCode: [String: Double] = [:]
    for value in currencyRates where value.rate.isFinite && value.rate > 0 {
        byCode[value.currency] = value.rate
    }
    var rates: [WalletContext.FiatCurrency: WalletContext.FiatRate] = [:]
    for currency in WalletContext.FiatCurrency.allCases {
        guard let perUsd = byCode[currency.code] else { continue }
        let perGram = perUsd * tonUsdRate
        guard perGram.isFinite, perGram > 0 else { continue }
        rates[currency] = WalletContext.FiatRate(unitsPerUsd: perUsd, unitsPerGram: perGram)
    }
    guard !rates.isEmpty else { return .failure(.invalidData) }
    return .success(rates)
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    private var isFiatRatesRefreshEligible: Bool {
        self.canUseNetworkRuntime && self.stateSubscriberCount > 0
    }

    func evaluateFiatRatesDemand() {
        guard self.isFiatRatesRefreshEligible else {
            self.cancelFiatRatesRefresh()
            return
        }
        guard self.fiatRefreshTask == nil else { return }
        let taskId = UUID()
        self.fiatRefreshTaskId = taskId
        self.fiatRefreshTask = Task { [weak self] in
            await self?.runFiatRatesRefresh(taskId: taskId)
        }
    }

    func cancelFiatRatesRefresh() {
        self.fiatRefreshTask?.cancel()
        self.fiatRefreshTask = nil
        self.fiatRefreshTaskId = nil
    }

    private func runFiatRatesRefresh(taskId: UUID) async {
        defer {
            if self.fiatRefreshTaskId == taskId {
                self.fiatRefreshTask = nil
                self.fiatRefreshTaskId = nil
            }
        }
        while !Task.isCancelled,
              self.fiatRefreshTaskId == taskId,
              self.isFiatRatesRefreshEligible {
            let result: Result<[FiatCurrency: FiatRate], SynchronizationError>
            do {
                result = try await WalletSignalRequestContext<Result<[FiatCurrency: FiatRate], SynchronizationError>>().run(
                    combineLatest(
                        self.engine.payments.currencyRates(),
                        self.engine.data.get(TelegramEngine.EngineData.Item.Configuration.App())
                    )
                    |> map { currencyRates, configuration in
                        walletFiatRatesResult(
                            currencyRates: currencyRates,
                            tonUsdRate: configuration.data?["ton_usd_rate"] as? Double
                        )
                    }
                    |> take(1)
                    |> castError(SynchronizationError.self)
                )
            } catch is CancellationError {
                return
            } catch {
                result = .failure(synchronizationError(error))
            }

            guard !Task.isCancelled,
                  self.fiatRefreshTaskId == taskId,
                  self.isFiatRatesRefreshEligible else {
                return
            }
            let rates: Resource<[FiatCurrency: FiatRate]>
            switch result {
            case let .success(value):
                let timestamp = currentWalletTimestamp()
                self.fiatLastSuccessfulAt = timestamp
                rates = .value(value, updatedAt: timestamp)
            case let .failure(error):
                self.logger.error("wallet_fiat_rates_refresh_failed", error)
                rates = .stale(
                    previous: self.currentState.fiat.rates.currentValue,
                    error: error,
                    lastSuccessfulAt: self.currentState.fiat.rates.lastSuccessfulAt ?? self.fiatLastSuccessfulAt
                )
            }
            self.replaceState(
                phase: self.currentState.phase,
                balance: self.currentState.balance,
                transactions: self.currentState.transactions,
                pendingTransfers: self.currentState.pendingTransfers,
                activeOperation: self.currentState.activeOperation,
                fiat: FiatState(selectedCurrency: self.currentState.fiat.selectedCurrency, rates: rates)
            )

            do {
                try await Task.sleep(nanoseconds: UInt64(walletFiatRatesRefreshInterval * 1_000_000_000))
            } catch {
                return
            }
        }
    }
}
