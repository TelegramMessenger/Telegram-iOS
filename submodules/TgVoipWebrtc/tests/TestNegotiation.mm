#import <XCTest/XCTest.h>

#include "api/task_queue/default_task_queue_factory.h"
#include "media/engine/webrtc_media_engine.h"
#include "api/audio_codecs/audio_encoder_factory_template.h"
#include "api/audio_codecs/audio_decoder_factory_template.h"
#include "api/audio_codecs/opus/audio_decoder_opus.h"
#include "api/audio_codecs/opus/audio_decoder_multi_channel_opus.h"
#include "api/audio_codecs/opus/audio_encoder_opus.h"
#include "api/audio_codecs/L16/audio_decoder_L16.h"
#include "api/audio_codecs/L16/audio_encoder_L16.h"

#include "StaticThreads.h"
#include "FakeAudioDeviceModule.h"
#include "platform/PlatformInterface.h"

#include "v2/ContentNegotiation.h"

namespace {
    class Context {
    public:
        Context(bool isOutgoing) :
        _isOutgoing(isOutgoing),
        _threads(tgcalls::StaticThreads::getThreads()),
        _taskQueueFactory(webrtc::CreateDefaultTaskQueueFactory()),
        _uniqueRandomIdGenerator(std::make_unique<rtc::UniqueRandomIdGenerator>()) {
            _threads->getWorkerThread()->Invoke<void>(RTC_FROM_HERE, [&]() {
                cricket::MediaEngineDependencies mediaDeps;
                mediaDeps.task_queue_factory = _taskQueueFactory.get();
                mediaDeps.audio_encoder_factory = webrtc::CreateAudioEncoderFactory<webrtc::AudioEncoderOpus, webrtc::AudioEncoderL16>();
                mediaDeps.audio_decoder_factory = webrtc::CreateAudioDecoderFactory<webrtc::AudioDecoderOpus, webrtc::AudioDecoderL16>();

                mediaDeps.video_encoder_factory = tgcalls::PlatformInterface::SharedInstance()->makeVideoEncoderFactory(true);
                mediaDeps.video_decoder_factory = tgcalls::PlatformInterface::SharedInstance()->makeVideoDecoderFactory();

                tgcalls::FakeAudioDeviceModule::Options options;
                options.num_channels = 1;
                _audioDeviceModule = tgcalls::FakeAudioDeviceModule::Creator(nullptr, nullptr, options)(_taskQueueFactory.get());
                
                mediaDeps.adm = _audioDeviceModule;

                _mediaEngine = cricket::CreateMediaEngine(std::move(mediaDeps));

                _channelManager = cricket::ChannelManager::Create(
                    std::move(_mediaEngine),
                    true,
                    _threads->getWorkerThread(),
                    _threads->getNetworkThread()
                );
            });

            _contentNegotiationContext = std::make_unique<tgcalls::ContentNegotiationContext>(isOutgoing, _uniqueRandomIdGenerator.get());
            _contentNegotiationContext->copyCodecsFromChannelManager(_channelManager.get(), isOutgoing);
        }

        ~Context() {
            _contentNegotiationContext.reset();
            
            _threads->getWorkerThread()->Invoke<void>(RTC_FROM_HERE, [&]() {
                _channelManager.reset();
                _mediaEngine.reset();
                _audioDeviceModule = nullptr;
            });
        }


    public:
        tgcalls::ContentNegotiationContext *contentNegotiationContext() const {
            return _contentNegotiationContext.get();
        }
        
        void assertSsrcs(std::vector<uint32_t> const &outgoingSsrcs, std::vector<uint32_t> const &incomingSsrcs) {
            std::set<uint32_t> incomingSsrcsSet;
            for (auto ssrc : incomingSsrcs) {
                incomingSsrcsSet.insert(ssrc);
            }
            
            std::set<uint32_t> outgoingSsrcsSet;
            for (auto ssrc : outgoingSsrcs) {
                outgoingSsrcsSet.insert(ssrc);
            }
            
            std::set<uint32_t> actualIncomingSsrcs;
            std::set<uint32_t> actualOutgoingSsrcs;
            
            auto coordinatedState = _contentNegotiationContext->coordinatedState();
            XCTAssert(coordinatedState != nullptr);
            
            for (const auto &content : coordinatedState->incomingContents) {
                actualIncomingSsrcs.insert(content.ssrc);
            }
            for (const auto &content : coordinatedState->outgoingContents) {
                actualOutgoingSsrcs.insert(content.ssrc);
            }
            
            XCTAssert(incomingSsrcsSet == actualIncomingSsrcs);
            XCTAssert(outgoingSsrcsSet == actualOutgoingSsrcs);
        }
        
        bool isContentsEqualToRemote(Context &remoteContext) {
            auto localCoordinatedState = _contentNegotiationContext->coordinatedState();
            auto remoteCoordinatedState = remoteContext.contentNegotiationContext()->coordinatedState();
            
            auto mediaContentComparator = [](tgcalls::signaling::MediaContent const &lhs, tgcalls::signaling::MediaContent const &rhs) -> bool {
                return lhs.ssrc < rhs.ssrc;
            };
            
            auto localIncomingContents = localCoordinatedState->incomingContents;
            std::sort(localIncomingContents.begin(), localIncomingContents.end(), mediaContentComparator);
            
            auto localOutgoingContents = localCoordinatedState->outgoingContents;
            std::sort(localOutgoingContents.begin(), localOutgoingContents.end(), mediaContentComparator);
            
            auto remoteIncomingContents = remoteCoordinatedState->incomingContents;
            std::sort(remoteIncomingContents.begin(), remoteIncomingContents.end(), mediaContentComparator);
            
            auto remoteOutgoingContents = remoteCoordinatedState->outgoingContents;
            std::sort(remoteOutgoingContents.begin(), remoteOutgoingContents.end(), mediaContentComparator);
            
            if (localIncomingContents != remoteOutgoingContents) {
                return false;
            }
            if (localOutgoingContents != remoteIncomingContents) {
                return false;
            }
            
            return true;
        }

    private:
        __unused bool _isOutgoing = false;
        std::shared_ptr<tgcalls::Threads> _threads;
        std::unique_ptr<webrtc::TaskQueueFactory> _taskQueueFactory;
        std::unique_ptr<rtc::UniqueRandomIdGenerator> _uniqueRandomIdGenerator;
        rtc::scoped_refptr<webrtc::AudioDeviceModule> _audioDeviceModule;
        std::unique_ptr<cricket::MediaEngineInterface> _mediaEngine;
        std::unique_ptr<cricket::ChannelManager> _channelManager;
        std::unique_ptr<tgcalls::ContentNegotiationContext> _contentNegotiationContext;
    };

std::unique_ptr<tgcalls::ContentNegotiationContext::NegotiationContents> copyNegotiationContents(tgcalls::ContentNegotiationContext::NegotiationContents *value) {
    if (!value) {
        return nullptr;
    }

    auto result = std::make_unique<tgcalls::ContentNegotiationContext::NegotiationContents>();
    result->exchangeId = value->exchangeId;
    result->contents = value->contents;

    return result;
}

void runUntilStableSequential(Context &localContext, Context &remoteContext) {
    for (int i = 0; i < 6; i++) {
        auto localOffer = localContext.contentNegotiationContext()->getPendingOffer();
        if (localOffer) {
            auto remoteAnswer = remoteContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(localOffer.get()));
            XCTAssert(remoteAnswer != nullptr);
            
            auto localResponse = localContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(remoteAnswer.get()));
            XCTAssert(localResponse == nullptr);
        } else {
            auto remoteOffer = remoteContext.contentNegotiationContext()->getPendingOffer();
            if (remoteOffer) {
                auto localAnswer = localContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(remoteOffer.get()));
                XCTAssert(localAnswer != nullptr);
                
                auto remoteResponse = remoteContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(localAnswer.get()));
                XCTAssert(remoteResponse == nullptr);
            } else {
                return;
            }
        }
    }
    
    XCTFail(@"Did not complete");
}

void runUntilStableConcurrent(Context &localContext, Context &remoteContext) {
    std::vector<std::unique_ptr<tgcalls::ContentNegotiationContext::NegotiationContents>> localNegotiationContent;
    std::vector<std::unique_ptr<tgcalls::ContentNegotiationContext::NegotiationContents>> remoteNegotiationContent;
    
    for (int i = 0; i < 6; i++) {
        std::unique_ptr<tgcalls::ContentNegotiationContext::NegotiationContents> nextLocalNegotiationContent;
        std::unique_ptr<tgcalls::ContentNegotiationContext::NegotiationContents> nextRemoteNegotiationContent;
        
        while (!localNegotiationContent.empty()) {
            auto content = std::move(localNegotiationContent[0]);
            localNegotiationContent.erase(localNegotiationContent.begin());
            
            nextRemoteNegotiationContent = remoteContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(content.get()));
        }
        while (!remoteNegotiationContent.empty()) {
            auto content = std::move(remoteNegotiationContent[0]);
            remoteNegotiationContent.erase(remoteNegotiationContent.begin());
            
            nextLocalNegotiationContent = localContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(content.get()));
        }
        
        if (nextLocalNegotiationContent) {
            localNegotiationContent.push_back(std::move(nextLocalNegotiationContent));
        }
        if (nextRemoteNegotiationContent) {
            remoteNegotiationContent.push_back(std::move(nextRemoteNegotiationContent));
        }
        
        auto localOffer = localContext.contentNegotiationContext()->getPendingOffer();
        if (localOffer) {
            localNegotiationContent.push_back(std::move(localOffer));
        }
        
        auto remoteOffer = remoteContext.contentNegotiationContext()->getPendingOffer();
        if (remoteOffer) {
            remoteNegotiationContent.push_back(std::move(remoteOffer));
        }
        
        if (localNegotiationContent.empty() && remoteNegotiationContent.empty()) {
            return;
        }
    }
    
    XCTFail(@"Did not complete");
}

}
 
@interface NegotiationTests : XCTestCase
@end
 
@implementation NegotiationTests
 
- (void)setUp {
    [super setUp];
    
    self.continueAfterFailure = false;
}
 
- (void)tearDown {
    [super tearDown];
}

- (void)testNegotiateEmpty {
    Context localContext(true);
    Context remoteContext(false);

    XCTAssert(localContext.contentNegotiationContext()->getPendingOffer() != nullptr);
    XCTAssert(remoteContext.contentNegotiationContext()->getPendingOffer() != nullptr);
}
 
- (void)testNegotiateAudioOnewayOutgoing {
    Context localContext(true);
    Context remoteContext(false);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    localContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Audio);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    auto offer = localContext.contentNegotiationContext()->getPendingOffer();
    XCTAssert(offer != nullptr);
    XCTAssert(offer->contents.size() == 1);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    XCTAssert(localContext.contentNegotiationContext()->getPendingOffer() == nullptr);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    auto response = remoteContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(offer.get()));
    XCTAssert(response != nullptr);
    XCTAssert(response->contents.size() == offer->contents.size());

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.size() == 1);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents[0].ssrc == offer->contents[0].ssrc);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    auto backOffer = remoteContext.contentNegotiationContext()->getPendingOffer();
    XCTAssert(backOffer != nullptr);
    XCTAssert(backOffer->contents.size() == 0);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.size() == 1);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents[0].ssrc == offer->contents[0].ssrc);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    auto responseToAnswer = localContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(response.get()));
    XCTAssert(responseToAnswer == nullptr);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.size() == 1);
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents[0].ssrc == offer->contents[0].ssrc);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.size() == 1);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents[0].ssrc == offer->contents[0].ssrc);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    auto nextOffer = localContext.contentNegotiationContext()->getPendingOffer();
    XCTAssert(nextOffer == nullptr);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.size() == 1);
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents[0].ssrc == offer->contents[0].ssrc);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.size() == 1);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents[0].ssrc == offer->contents[0].ssrc);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
}

- (void)testNegotiateAudioOnewayIncoming {
    Context localContext(true);
    Context remoteContext(false);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    remoteContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Audio);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    auto offer = localContext.contentNegotiationContext()->getPendingOffer();
    XCTAssert(offer != nullptr);
    XCTAssert(offer->contents.empty());

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    XCTAssert(localContext.contentNegotiationContext()->getPendingOffer() == nullptr);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    auto response = remoteContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(offer.get()));
    XCTAssert(response != nullptr);
    XCTAssert(response->contents.size() == offer->contents.size());

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    auto backOffer = remoteContext.contentNegotiationContext()->getPendingOffer();
    XCTAssert(backOffer != nullptr);
    XCTAssert(backOffer->contents.size() == 1);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    auto responseToAnswer = localContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(response.get()));
    XCTAssert(responseToAnswer == nullptr);
    
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    
    auto responseToBackOffer = localContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(backOffer.get()));
    XCTAssert(responseToBackOffer != nullptr);
    XCTAssert(responseToBackOffer->contents.size() == 1);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.size() == 1);
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents[0].ssrc == backOffer->contents[0].ssrc);
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    
    auto responseToBackOfferAnswer = remoteContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(responseToBackOffer.get()));
    XCTAssert(responseToBackOfferAnswer == nullptr);

    XCTAssert(localContext.contentNegotiationContext()->getPendingOffer() == nullptr);
    XCTAssert(remoteContext.contentNegotiationContext()->getPendingOffer() == nullptr);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.size() == 1);
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents[0].ssrc == backOffer->contents[0].ssrc);
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.size() == 1);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents[0].ssrc == backOffer->contents[0].ssrc);
}

- (void)testNegotiateAudioTwoway {
    Context localContext(true);
    Context remoteContext(false);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    localContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Audio);
    remoteContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Audio);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    auto offer = localContext.contentNegotiationContext()->getPendingOffer();
    XCTAssert(offer != nullptr);
    XCTAssert(offer->contents.size() == 1);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    XCTAssert(localContext.contentNegotiationContext()->getPendingOffer() == nullptr);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    auto response = remoteContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(offer.get()));
    XCTAssert(response != nullptr);
    XCTAssert(response->contents.size() == offer->contents.size());

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.size() == 1);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents[0].ssrc == offer->contents[0].ssrc);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    auto backOffer = remoteContext.contentNegotiationContext()->getPendingOffer();
    XCTAssert(backOffer != nullptr);
    XCTAssert(backOffer->contents.size() == 1);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.size() == 1);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents[0].ssrc == offer->contents[0].ssrc);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());

    auto responseToAnswer = localContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(response.get()));
    XCTAssert(responseToAnswer == nullptr);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.empty());
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.size() == 1);
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents[0].ssrc == offer->contents[0].ssrc);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.size() == 1);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents[0].ssrc == offer->contents[0].ssrc);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    
    XCTAssert(localContext.contentNegotiationContext()->getPendingOffer() == nullptr);

    auto responseToBackOffer = localContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(backOffer.get()));
    XCTAssert(responseToBackOffer != nullptr);
    XCTAssert(responseToBackOffer->contents.size() == 1);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.size() == 1);
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents[0].ssrc == backOffer->contents[0].ssrc);
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.size() == 1);
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents[0].ssrc == offer->contents[0].ssrc);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.size() == 1);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents[0].ssrc == offer->contents[0].ssrc);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.empty());
    
    auto responseToBackOfferAnswer = remoteContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(responseToBackOffer.get()));
    XCTAssert(responseToBackOfferAnswer == nullptr);

    XCTAssert(localContext.contentNegotiationContext()->getPendingOffer() == nullptr);
    XCTAssert(remoteContext.contentNegotiationContext()->getPendingOffer() == nullptr);

    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents.size() == 1);
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->incomingContents[0].ssrc == backOffer->contents[0].ssrc);
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents.size() == 1);
    XCTAssert(localContext.contentNegotiationContext()->coordinatedState()->outgoingContents[0].ssrc == offer->contents[0].ssrc);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents.size() == 1);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->incomingContents[0].ssrc == offer->contents[0].ssrc);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents.size() == 1);
    XCTAssert(remoteContext.contentNegotiationContext()->coordinatedState()->outgoingContents[0].ssrc == backOffer->contents[0].ssrc);
}

- (void)testConcurrentOffers {
    Context localContext(true);
    Context remoteContext(false);

    auto localOffer = localContext.contentNegotiationContext()->getPendingOffer();
    XCTAssert(localOffer != nullptr);
    
    auto remoteOffer = remoteContext.contentNegotiationContext()->getPendingOffer();
    XCTAssert(remoteOffer != nullptr);
    
    auto localAnswer = remoteContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(localOffer.get()));
    XCTAssert(localAnswer != nullptr);
    XCTAssert(localAnswer->exchangeId == localOffer->exchangeId);
    
    auto remoteAnswer = localContext.contentNegotiationContext()->setRemoteNegotiationContent(copyNegotiationContents(remoteOffer.get()));
    XCTAssert(remoteAnswer == nullptr);
}

- (void)service_runUntilStable1Using:(std::function<void(Context &localContext, Context &remoteContext)>)runUntilStable {
    Context localContext(true);
    Context remoteContext(false);
    
    runUntilStable(localContext, remoteContext);
    
    localContext.assertSsrcs({}, {});
    remoteContext.assertSsrcs({}, {});
    localContext.isContentsEqualToRemote(remoteContext);
    
    auto localAudioId = localContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Audio);
    
    runUntilStable(localContext, remoteContext);
    
    auto localAudioSsrc = localContext.contentNegotiationContext()->outgoingChannelSsrc(localAudioId);
    XCTAssert(localAudioSsrc);
    
    localContext.assertSsrcs({ localAudioSsrc.value() }, {});
    remoteContext.assertSsrcs({}, { localAudioSsrc.value() });
    localContext.isContentsEqualToRemote(remoteContext);
    
    auto remoteAudioId = remoteContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Audio);
    
    runUntilStable(localContext, remoteContext);
    
    auto remoteAudioSsrc = remoteContext.contentNegotiationContext()->outgoingChannelSsrc(remoteAudioId);
    XCTAssert(remoteAudioSsrc);
    
    localContext.assertSsrcs({ localAudioSsrc.value() }, { remoteAudioSsrc.value() });
    remoteContext.assertSsrcs({ remoteAudioSsrc.value() }, { localAudioSsrc.value() });
    localContext.isContentsEqualToRemote(remoteContext);
    
    auto remoteVideoId = remoteContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Video);
    
    runUntilStable(localContext, remoteContext);
    
    auto remoteVideoSsrc = remoteContext.contentNegotiationContext()->outgoingChannelSsrc(remoteVideoId);
    XCTAssert(remoteVideoSsrc);
    
    localContext.assertSsrcs({ localAudioSsrc.value() }, { remoteAudioSsrc.value(), remoteVideoSsrc.value() });
    remoteContext.assertSsrcs({ remoteAudioSsrc.value(), remoteVideoSsrc.value() }, { localAudioSsrc.value() });
    localContext.isContentsEqualToRemote(remoteContext);
    
    auto localVideoId = localContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Video);
    
    runUntilStable(localContext, remoteContext);
    
    auto localVideoSsrc = localContext.contentNegotiationContext()->outgoingChannelSsrc(localVideoId);
    XCTAssert(localVideoSsrc);
    
    localContext.assertSsrcs({ localAudioSsrc.value(), localVideoSsrc.value() }, { remoteAudioSsrc.value(), remoteVideoSsrc.value() });
    remoteContext.assertSsrcs({ remoteAudioSsrc.value(), remoteVideoSsrc.value() }, { localAudioSsrc.value(), localVideoSsrc.value() });
    localContext.isContentsEqualToRemote(remoteContext);
    
    auto remoteScreencastId = remoteContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Video);
    
    runUntilStable(localContext, remoteContext);
    
    auto remoteScreencastSsrc = remoteContext.contentNegotiationContext()->outgoingChannelSsrc(remoteScreencastId);
    XCTAssert(remoteScreencastSsrc);
    
    localContext.assertSsrcs({ localAudioSsrc.value(), localVideoSsrc.value() }, { remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() });
    remoteContext.assertSsrcs({ remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() }, { localAudioSsrc.value(), localVideoSsrc.value() });
    localContext.isContentsEqualToRemote(remoteContext);
    
    localContext.contentNegotiationContext()->removeOutgoingChannel(localVideoId);
    
    // local removal is reflected right away
    localContext.assertSsrcs({ localAudioSsrc.value() }, { remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() });
    remoteContext.assertSsrcs({ remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() }, { localAudioSsrc.value(), localVideoSsrc.value() });
    localVideoSsrc = localContext.contentNegotiationContext()->outgoingChannelSsrc(localVideoId);
    XCTAssert(!localVideoSsrc);
    
    runUntilStable(localContext, remoteContext);
    
    localVideoSsrc = localContext.contentNegotiationContext()->outgoingChannelSsrc(localVideoId);
    XCTAssert(!localVideoSsrc);
    
    localContext.assertSsrcs({ localAudioSsrc.value() }, { remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() });
    remoteContext.assertSsrcs({ remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() }, { localAudioSsrc.value() });
    localContext.isContentsEqualToRemote(remoteContext);
    
    localVideoId = localContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Video);
    
    runUntilStable(localContext, remoteContext);
    
    localVideoSsrc = localContext.contentNegotiationContext()->outgoingChannelSsrc(localVideoId);
    XCTAssert(localVideoSsrc);
    
    localContext.assertSsrcs({ localAudioSsrc.value(), localVideoSsrc.value() }, { remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() });
    remoteContext.assertSsrcs({ remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() }, { localAudioSsrc.value(), localVideoSsrc.value() });
    localContext.isContentsEqualToRemote(remoteContext);
}

- (void)service_runUntilStable2Using:(std::function<void(Context &localContext, Context &remoteContext)>)runUntilStable {
    Context localContext(true);
    Context remoteContext(false);
    
    runUntilStable(localContext, remoteContext);
    
    localContext.assertSsrcs({}, {});
    remoteContext.assertSsrcs({}, {});
    localContext.isContentsEqualToRemote(remoteContext);
    
    auto localAudioId = localContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Audio);
    auto remoteAudioId = remoteContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Audio);
    
    runUntilStable(localContext, remoteContext);
    
    auto localAudioSsrc = localContext.contentNegotiationContext()->outgoingChannelSsrc(localAudioId);
    XCTAssert(localAudioSsrc);
    
    auto remoteAudioSsrc = remoteContext.contentNegotiationContext()->outgoingChannelSsrc(remoteAudioId);
    XCTAssert(remoteAudioSsrc);
    
    localContext.assertSsrcs({ localAudioSsrc.value() }, { remoteAudioSsrc.value() });
    remoteContext.assertSsrcs({ remoteAudioSsrc.value() }, { localAudioSsrc.value() });
    localContext.isContentsEqualToRemote(remoteContext);
    
    auto remoteVideoId = remoteContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Video);
    auto localVideoId = localContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Video);
    
    runUntilStable(localContext, remoteContext);
    
    auto remoteVideoSsrc = remoteContext.contentNegotiationContext()->outgoingChannelSsrc(remoteVideoId);
    XCTAssert(remoteVideoSsrc);
    
    auto localVideoSsrc = localContext.contentNegotiationContext()->outgoingChannelSsrc(localVideoId);
    XCTAssert(localVideoSsrc);
    
    localContext.assertSsrcs({ localAudioSsrc.value(), localVideoSsrc.value() }, { remoteAudioSsrc.value(), remoteVideoSsrc.value() });
    remoteContext.assertSsrcs({ remoteAudioSsrc.value(), remoteVideoSsrc.value() }, { localAudioSsrc.value(), localVideoSsrc.value() });
    localContext.isContentsEqualToRemote(remoteContext);
    
    auto remoteScreencastId = remoteContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Video);
    
    runUntilStable(localContext, remoteContext);
    
    auto remoteScreencastSsrc = remoteContext.contentNegotiationContext()->outgoingChannelSsrc(remoteScreencastId);
    XCTAssert(remoteScreencastSsrc);
    
    localContext.assertSsrcs({ localAudioSsrc.value(), localVideoSsrc.value() }, { remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() });
    remoteContext.assertSsrcs({ remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() }, { localAudioSsrc.value(), localVideoSsrc.value() });
    localContext.isContentsEqualToRemote(remoteContext);
    
    localContext.contentNegotiationContext()->removeOutgoingChannel(localVideoId);
    
    // local removal is reflected right away
    localContext.assertSsrcs({ localAudioSsrc.value() }, { remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() });
    remoteContext.assertSsrcs({ remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() }, { localAudioSsrc.value(), localVideoSsrc.value() });
    localVideoSsrc = localContext.contentNegotiationContext()->outgoingChannelSsrc(localVideoId);
    XCTAssert(!localVideoSsrc);
    
    runUntilStable(localContext, remoteContext);
    
    localVideoSsrc = localContext.contentNegotiationContext()->outgoingChannelSsrc(localVideoId);
    XCTAssert(!localVideoSsrc);
    
    localContext.assertSsrcs({ localAudioSsrc.value() }, { remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() });
    remoteContext.assertSsrcs({ remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() }, { localAudioSsrc.value() });
    localContext.isContentsEqualToRemote(remoteContext);
    
    localVideoId = localContext.contentNegotiationContext()->addOutgoingChannel(tgcalls::signaling::MediaContent::Type::Video);
    
    runUntilStable(localContext, remoteContext);
    
    localVideoSsrc = localContext.contentNegotiationContext()->outgoingChannelSsrc(localVideoId);
    XCTAssert(localVideoSsrc);
    
    localContext.assertSsrcs({ localAudioSsrc.value(), localVideoSsrc.value() }, { remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() });
    remoteContext.assertSsrcs({ remoteAudioSsrc.value(), remoteVideoSsrc.value(), remoteScreencastSsrc.value() }, { localAudioSsrc.value(), localVideoSsrc.value() });
    localContext.isContentsEqualToRemote(remoteContext);
}
- (void)testConvergenceSequential1 {
    [self service_runUntilStable1Using:&runUntilStableSequential];
}

- (void)testConvergenceSequential2 {
    [self service_runUntilStable2Using:&runUntilStableSequential];
}

- (void)testConvergenceConcurrent1 {
    [self service_runUntilStable1Using:&runUntilStableConcurrent];
}

- (void)testConvergenceConcurrent2 {
    [self service_runUntilStable2Using:&runUntilStableConcurrent];
}

@end
