#pragma once

#include <memory>

#include "control/controlproxy.h"
#include "rendergraph/geometrynode.h"
#include "util/class.h"
#include "waveform/renderers/allshader/waveformrenderersignalbase.h"

namespace allshader {
class WaveformRendererFiltered;
} // namespace allshader

class allshader::WaveformRendererFiltered final
        : public allshader::WaveformRendererSignalBase,
          public rendergraph::GeometryNode {
  public:
    explicit WaveformRendererFiltered(WaveformWidgetRenderer* waveformWidget,
            bool rgbStacked,
            ::WaveformRendererSignalBase::Options options);

    // Pure virtual from WaveformRendererSignalBase, not used
    void onSetup(const QDomNode& node) override;

    // Virtuals for rendergraph::Node
    void preprocess() override;

  private:
    const bool m_bRgbStacked;
#ifdef FLXXX3
    // ADVANCED SETTINGS > WAVEFORM: size of each layer (blue = low, orange = mid, brown = the
    // inner part of mid, cream = high), 1 = as before.
    std::unique_ptr<ControlProxy> m_pSizeLow;
    std::unique_ptr<ControlProxy> m_pSizeMid;
    std::unique_ptr<ControlProxy> m_pSizeBrown;
    std::unique_ptr<ControlProxy> m_pSizeHigh;
#endif
    bool preprocessInner();

    DISALLOW_COPY_AND_ASSIGN(WaveformRendererFiltered);
};
