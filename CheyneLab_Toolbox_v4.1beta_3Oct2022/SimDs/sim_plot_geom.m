%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function sim_draw_geom(geomFile)
% 
% make 3D plot of sensor geometry
% 
% D. Cheyne, March, 2011
%
% make a 3D plot of sensor geometry from a .geom file
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function sim_draw_geom(geomfile)

drawAllCoils = 1;
drawSolid = 0;

spinImage = 0;
makeMovie = 0;


hMainFigure = figure('Color','white','position', [512, 512, 700 400] );

hold on;
view(35,15);


if drawAllCoils
    xlim([-30 30]);
    ylim([-30 30]);
    zlim([0 20]);
else
    xlim([-15 15]);
    ylim([-15 15]);
    zlim([-5 20]);
end
    
    
t = importdata(geomfile);

nchans = size(t.data,1);
coil1 = zeros(nchans,3);
coil2 = zeros(nchans,3);
pvec = zeros(nchans,3);

% build a table of the coil locations
area = t.data(1,5);
gradOrder = t.data(1,3);
meanBaseline = 0;

coilRadius = sqrt( area / pi);

sumB = 0;
for i=1:nchans
    coil1(i,1:3) = t.data(i,6:8);

    if (gradOrder > 1)
        coil2(i,1:3) = t.data(i,14:16);
        d = coil2(i,1:3) - coil1(i,1:3);  % actual CTF pvecs have random orientation !
        len = norm(d);
        pvec(i,1:3) = d / len;
        sumB = sumB + len;    
    end
end

if (gradOrder > 1)
    meanBaseline = sumB / nchans;
end

% get mean radius as distance from head origin and compute centroid of coil 1
sumR = 0.0;
sumSphereR = 0.0;
origin = [0 0 5];

sumCoils = [0 0 0];
for i=1:nchans
    loc = coil1(i,1:3);
    sumCoils = sumCoils + loc;
    sumR = sumR + norm(loc);
    r0 = loc(1:3) - origin(1:3);
    sumSphereR = sumSphereR + norm(r0);
end
meanHeadRadius = sumR / nchans;

meanSphereRadius = sumSphereR / nchans;
centroid = sumCoils / nchans;

% get mean radius as distance from centroid of all coils (helmet)
sumR = 0.0;
for i=1:nchans
    loc = coil1(i,1:3);
    d = loc - centroid;
    sumR = sumR + norm(d);
end
meanHelmetRadius = sumR / nchans;

maxX = max(coil1(:,1));
minX = min(coil1(:,1));

maxY = max(coil1(:,2));
minY = min(coil1(:,2));

maxZ = max(coil1(:,3));
minZ = min(coil1(:,3));


fprintf('\nfile %s:\n numSensors %d, mean baseline %.1f cm, meanRadius = %.1f cm, helmet center = (%.1f %.1f, %.1f), meanHelmetRadius = %.1f\n', ...
    geomfile, nchans, meanBaseline, meanHeadRadius, centroid, meanHelmetRadius);
% draw gradiometers

coilRadius = 1;


for i=1:nchans

    tf=hgtransform;
    [x y z] = cylinder(coilRadius);
    h = surface(x,y,z,'parent',tf);      
    set(h,'FaceColor','blue','EdgeColor','blue');

    if (drawSolid)
        shading interp;
    end

    pt1=coil1(i,1:3);        

    % get the unit direction vector
    vec = pvec(i,1:3);

    % make cylinder a circle 
    if (~drawSolid)
        len = 0.1;
    else
        len = meanBaseline;
    end

    % some code from web to plot rotated cylinders 
    %

    % use vec to compute a rotation axis and angle
    % and draw a rotated cylinder object...
    rot_axis = cross([0 0 1],vec);
    if norm(rot_axis) > eps
       rot_angle = asin(norm(rot_axis));
       if (dot([0 0 1],vec) < 0)
           rot_angle = pi-rot_angle;
       end
    else
       rot_axis = [0 0 1];
       rot_angle = 0;
    end


    % generate a transform matrix that translate to pt1, rotates to along with the new axis, and scales to the correct length.
    set(tf,'matrix',makehgtform('translate',pt1,'axisrotate',rot_axis,rot_angle,'scale',[1 1 len]));


    if (gradOrder == 2 && drawAllCoils)       
        tf=hgtransform;
        h = surface(x,y,z,'parent',tf, 'FaceAlpha',0.5, 'EdgeAlpha',0.5);


        set(h,'FaceColor','blue','EdgeColor','blue');
        pt1=coil2(i,1:3);        

        vec = pvec(i,1:3);
        len = norm(vec);
        vec = vec/len;
        len = 0.1;
        rot_axis = cross([0 0 1],vec);
        if norm(rot_axis) > eps
           rot_angle = asin(norm(rot_axis));
           if (dot([0 0 1],vec) < 0)
               rot_angle = pi-rot_angle;
           end
        else
           rot_axis = [0 0 1];
           rot_angle = 0;
        end

        % generate a transform matrix that translate to pt1, rotates to along with the new axis, and scales to the correct length.
        set(tf,'matrix',makehgtform('translate',pt1,'axisrotate',rot_axis,rot_angle,'scale',[1 1 len]));
    end

end  % next channel




hold off;

%tt = title(tstr);
% set(tt,'Interpreter','none', 'fontsize',9, 'fontweight','bold');


if (spinImage)
    axis off;

    axis vis3d
    for i=1:72
       camorbit(5,0)
       drawnow
       if makeMovie
            fArray(i)=getframe(hMainFigure);        
       end
    end
    if makeMovie
        movie2avi(fArray,'plot_geom_movie.avi');
    end
    
end



                       