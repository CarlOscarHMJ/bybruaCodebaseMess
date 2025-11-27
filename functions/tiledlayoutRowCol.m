function [layout,nexttileRowCol] = tiledlayoutRowCol(nRows,nCols,varargin)
%TILEDLAYOUTROWCOL Create tiled layout with row/column addressing and span support

layout = tiledlayout(nRows,nCols,varargin{:});
nexttileRowCol = @innerNexttileRowCol;

    function tile = innerNexttileRowCol(row,col,varargin)
        rowSpan = 1;
        colSpan = 1;
        keepMask = true(size(varargin));
        k = 1;
        while k <= numel(varargin)-1
            key = varargin{k};
            if ischar(key) || isstring(key)
                keyLower = lower(string(key));
                if keyLower == "colspan"
                    colSpan = varargin{k+1};
                    keepMask([k k+1]) = false;
                    k = k + 2;
                    continue
                elseif keyLower == "rowspan"
                    rowSpan = varargin{k+1};
                    keepMask([k k+1]) = false;
                    k = k + 2;
                    continue
                end
            end
            k = k + 1;
        end

        nexttileArgs = varargin(keepMask);
        tileIndex = (row - 1) * nCols + col;

        if rowSpan == 1 && colSpan == 1
            tile = nexttile(tileIndex,nexttileArgs{:});
        else
            tile = nexttile(tileIndex,[rowSpan colSpan],nexttileArgs{:});
        end
    end
end
