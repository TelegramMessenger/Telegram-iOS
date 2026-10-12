//
//   Copyright 2015 Pixar
//
//   Licensed under the terms set forth in the LICENSE.txt file available at
//   https://opensubdiv.org/license.
//

#ifndef OPENSUBDIV3_FAR_STENCILBUILDER_H
#define OPENSUBDIV3_FAR_STENCILBUILDER_H

#include <vector>

#include "../version.h"
#include "../far/stencilTable.h"

namespace OpenSubdiv {
namespace OPENSUBDIV_VERSION {

namespace Far {
namespace internal {

template <typename REAL> class WeightTable;

template <typename REAL>
class StencilBuilder {
public:
    StencilBuilder(int coarseVertCount, 
                   bool genCtrlVertStencils=true,
                   bool compactWeights=true);
    ~StencilBuilder();

    // TODO: noncopyable.

    size_t GetNumVerticesTotal() const;

    int GetNumVertsInStencil(size_t stencilIndex) const;

    void SetCoarseVertCount(int numVerts);

    // Mapping from stencil[i] to its starting offset in the sources[] and weights[] arrays;
    std::vector<int> const& GetStencilOffsets() const;

    // The number of contributing sources and weights in stencil[i]
    std::vector<int> const& GetStencilSizes() const;

    // The absolute source vertex offsets.
    std::vector<int> const& GetStencilSources() const;

    // The individual vertex weights, each weight is paired with one source.
    std::vector<REAL> const& GetStencilWeights() const;
    std::vector<REAL> const& GetStencilDuWeights() const;
    std::vector<REAL> const& GetStencilDvWeights() const;
    std::vector<REAL> const& GetStencilDuuWeights() const;
    std::vector<REAL> const& GetStencilDuvWeights() const;
    std::vector<REAL> const& GetStencilDvvWeights() const;

    // Vertex Facade.
    class Index {
    public:
        Index(StencilBuilder* owner, int index) 
            : _owner(owner)
            , _index(index)
        {}

        // Add with point/vertex weight only.
        void AddWithWeight(Index const & src, REAL weight);
        void AddWithWeight(StencilReal<REAL> const& src, REAL weight);

        // Add with first derivative.
        void AddWithWeight(StencilReal<REAL> const& src,
            REAL weight, REAL du, REAL dv);

        // Add with first and second derivatives.
        void AddWithWeight(StencilReal<REAL> const& src,
            REAL weight, REAL du, REAL dv, REAL duu, REAL duv, REAL dvv);

        Index operator[](int index) const {
            return Index(_owner, index+_index);
        }

        int GetOffset() const { return _index; }

        void Clear() {/*nothing to do here*/}
    private:
        StencilBuilder* _owner;
        int _index;
    };

private:
    WeightTable<REAL>* _weightTable;
};

} // end namespace internal
} // end namespace Far
} // end namespace OPENSUBDIV_VERSION
} // end namespace OpenSubdiv

#endif // FAR_STENCILBUILDER_H
